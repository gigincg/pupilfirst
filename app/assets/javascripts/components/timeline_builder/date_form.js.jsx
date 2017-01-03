class TimelineBuilderDateForm extends React.Component {
  constructor(props) {
    super(props);

    let startDate = (props.selectedDate == null) ? this.today() : props.selectedDate;
    this.state = {date: startDate};

    this.handleChange = this.handleChange.bind(this);
    this.handleSubmit = this.handleSubmit.bind(this);
  }

  componentDidMount() {
    $('.js-timeline-builder__date-input').datetimepicker({
      startDate: this.state.date,
      scrollInput: false,
      scrollMonth: false,
      format: 'Y-m-d',
      timepicker: false,
      onSelectDate: this.handleChange
    })
  }

  componentWillUnmount() {
    $('.js-timeline-builder__date-input').datetimepicker('destroy');
  }

  today() {
    return moment().format('YYYY-MM-DD');
  }

  handleSubmit(event) {
    event.preventDefault()

    let submitDate = this.state.date;

    if (submitDate == null) {
      submitDate = this.today()
      this.setState({date: submitDate});
    }

    this.props.addAttachmentCB('date', {value: submitDate, hideDateForm: true});
  }

  handleChange() {
    let m = moment($('.js-timeline-builder__date-input').val(), 'YYYY-MM-DD');
    let newDate = '';

    if (m.isValid()) {
      newDate = m.format('YYYY-MM-DD');
    } else {
      newDate = this.today();
    }

    this.setState({date: newDate});
    this.props.addAttachmentCB('date', {value: newDate});
  }

  render() {
    return (
      <div className="form-inline timeline-builder__attachment-datepicker-form clearfix">
        <label className="col-md-2 form-group col-form-label text-xs-right">Date of event</label>
        <div className="col-md-9 form-group">
          <label className="sr-only" htmlFor="timeline-builder__date-input">Date of Event</label>
          <input id="timeline-builder__date-input" type="text" className="js-timeline-builder__date-input timeline-builder__date-input form-control" placeholder="YYYY-MM-DD" onChange={ this.handleChange }/>
        </div>
        <div className="col-md-1 form-group timeline-builder__attachment-datepicker-form-btn">
          <button type="submit" className="btn btn-secondary timeline-builder__attachment-button" onClick={ this.handleSubmit }>
            <i className="fa fa-check"/>
          </button>
        </div>
      </div>
    )
  }
}

TimelineBuilderDateForm.props = {
  selectedDate: React.PropTypes.string,
  addAttachmentCB: React.PropTypes.func
};