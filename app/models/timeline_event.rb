# frozen_string_literal: true

class TimelineEvent < ApplicationRecord
  belongs_to :target
  belongs_to :improved_timeline_event, class_name: 'TimelineEvent', optional: true
  belongs_to :evaluator, class_name: 'Faculty', optional: true

  has_many :target_evaluation_criteria, through: :target
  has_many :evaluation_criteria, through: :target_evaluation_criteria
  has_many :startup_feedback, dependent: :destroy
  has_many :timeline_event_files, dependent: :destroy
  has_one :improvement_of, class_name: 'TimelineEvent', foreign_key: 'improved_timeline_event_id', dependent: :nullify, inverse_of: :improved_timeline_event
  has_many :timeline_event_grades, dependent: :destroy
  has_many :timeline_event_owners, dependent: :destroy
  has_many :founders, through: :timeline_event_owners

  serialize :links

  delegate :founder_event?, to: :target
  delegate :title, to: :target

  MAX_DESCRIPTION_CHARACTERS = 500

  validates :description, presence: true

  accepts_nested_attributes_for :timeline_event_files, allow_destroy: true

  scope :from_admitted_startups, -> { joins(:founders).where(founders: { startup: Startup.admitted }) }
  scope :not_private, -> { joins(:target).where.not(targets: { role: Target::ROLE_FOUNDER }) }
  scope :not_improved, -> { joins(:target).where(improved_timeline_event_id: nil) }
  scope :not_auto_verified, -> { joins(:evaluation_criteria).distinct }
  scope :auto_verified, -> { where.not(id: not_auto_verified) }
  scope :passed, -> { where.not(passed_at: nil) }
  scope :pending_review, -> { not_auto_verified.where(evaluator_id: nil) }
  scope :evaluated_by_faculty, -> { where.not(evaluator_id: nil) }
  scope :from_founders, ->(founders) { joins(:timeline_event_owners).where(timeline_event_owners: { founder: founders }) }

  after_initialize :make_links_an_array

  def make_links_an_array
    self.links ||= []
  end

  before_save :ensure_links_is_an_array

  def ensure_links_is_an_array
    self.links = [] if links.nil?
  end

  # Accessors used by timeline builder form to create TimelineEventFile entries.
  # Should contain a hash: { identifier_key => uploaded_file, ... }
  attr_accessor :files

  # Writer used by timeline builder form to supply info about new / to-delete files.
  attr_writer :files_metadata

  def files_metadata
    @files_metadata || []
  end

  def files_metadata_json
    timeline_event_files.map do |te_file|
      {
        identifier: te_file.id,
        title: te_file.title,
        private: te_file.private?,
        persisted: true
      }
    end.to_json
  end

  # Return serialized links so that AA TimelineEvent#new/edit can use it.
  def serialized_links
    links.to_json
  end

  # Accept links in serialized form.
  def serialized_links=(links_string)
    self.links = JSON.parse(links_string).map(&:symbolize_keys)
  end

  after_save :update_timeline_event_files

  def update_timeline_event_files
    # Go through files metadata, and perform create / delete.
    files_metadata.each do |file_metadata|
      if file_metadata['persisted']
        # Delete persisted files if they've been flagged.
        if file_metadata['delete']
          timeline_event_files.find(file_metadata['identifier']).destroy!
        end
      else
        # Create non-persisted files.
        timeline_event_files.create!(
          title: file_metadata['title'],
          file: files[file_metadata['identifier']],
          private: file_metadata['private']
        )
      end
    end
  end

  def reviewed?
    timeline_event_grades.present?
  end

  def public_link?
    links.reject { |l| l[:private] }.present?
  end

  def attachments_for_founder(founder)
    privileged = privileged_founder?(founder)
    attachments = []

    timeline_event_files.each do |file|
      next if file.private? && !privileged

      attachments << { file: file, title: file.title, private: file.private? }
    end

    links.each do |link|
      next if link[:private] && !privileged

      attachments << link
    end

    attachments
  end

  def founder_or_startup
    founder_event? ? founder : startup
  end

  def improved_event_candidates
    founder_or_startup.timeline_events
      .where('created_at > ?', created_at)
      .where.not(id: id).order('created_at DESC')
  end

  def share_url
    Rails.application.routes.url_helpers.student_timeline_event_show_url(
      id: founder.id,
      event_id: id,
      event_title: title.parameterize
    )
  end

  def overall_grade_from_score
    return if score.blank?

    { 1 => 'good', 2 => 'great', 3 => 'wow' }[score.floor]
  end

  # TODO: Remove TimelineEvent#startup when possible.
  def startup
    first_founder = founders.first

    raise "TimelineEvent##{id} does not have any linked founders" if first_founder.blank?

    # TODO: This is a hack. Remove TimelineEvent#startup method after all of its usages have been deleted.
    first_founder.startup
  end

  def founder
    founders.first
  end

  def passed?
    passed_at.present?
  end

  def team_event?
    target.team_target?
  end

  def pending_review?
    passed_at.blank? && evaluator_id.blank?
  end

  private

  def privileged_founder?(founder)
    founder.present? && startup.founders.include?(founder)
  end
end
