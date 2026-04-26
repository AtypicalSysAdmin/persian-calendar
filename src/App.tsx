import { useState, useMemo } from 'react'
import moment from 'jalali-moment'

const persianWeekdays = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج']
const gregorianWeekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
const persianMonths: Record<string, string> = {
  Farvardin: 'فروردین',
  Ordibehesht: 'اردیبهشت',
  Khordaad: 'خرداد',
  Tir: 'تیر',
  Mordaad: 'مرداد',
  Shahrivar: 'شهریور',
  Mehr: 'مهر',
  Aabaan: 'آبان',
  Aazar: 'آذر',
  Dey: 'دی',
  Bahman: 'بهمن',
  Esfand: 'اسفند'
}

const toPersianNumber = (num: number | string): string => {
  const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹']
  return String(num).replace(/\d/g, d => persianDigits[parseInt(d)])
}

const getPersianMonthName = (monthName: string): string => {
  return persianMonths[monthName] || monthName
}

function App() {
  const [selectedDate, setSelectedDate] = useState(moment().clone())
  const [currentJalali, setCurrentJalali] = useState(() => moment().clone().startOf('jMonth'))
  const [currentGregorian, setCurrentGregorian] = useState(() => moment().clone().startOf('month'))

  const today = moment().clone()

  const jalaliCal = useMemo(() => {
    const start = currentJalali.clone()
    const days: { jalali: number; gregorian: string; gregorianShort: string; dayOfWeek: number }[] = []
    
    const startDayOfWeek = start.day()
    
    // Add empty cells for days before the first of the month
    for (let i = 0; i < startDayOfWeek; i++) {
      days.push({ jalali: 0, gregorian: '', gregorianShort: '', dayOfWeek: i })
    }
    
    const daysInMonth = start.daysInMonth()
    for (let i = 1; i <= daysInMonth; i++) {
      const date = start.clone().add(i - 1, 'days')
      const gregorian = date.format('YYYY-MM-DD')
      days.push({
        jalali: i,
        gregorian,
        gregorianShort: date.format('D'),
        dayOfWeek: date.day()
      })
    }
    
    return { days, monthName: start.format('jMMMM'), year: start.format('jYYYY') }
  }, [currentJalali])

  const gregorianCal = useMemo(() => {
    const start = currentGregorian.clone()
    const days: { day: number; jalali: string; jalaliShort: string; dayOfWeek: number }[] = []
    
    const firstDayOfWeek = start.day()
    
    for (let i = 0; i < firstDayOfWeek; i++) {
      days.push({ day: 0, jalali: '', jalaliShort: '', dayOfWeek: i })
    }
    
    const daysInMonth = start.daysInMonth()
    for (let i = 1; i <= daysInMonth; i++) {
      const date = start.clone().add(i - 1, 'days')
      const jalali = date.format('jYYYY-jMM-jDD')
      days.push({
        day: i,
        jalali,
        jalaliShort: date.format('jD'),
        dayOfWeek: date.day()
      })
    }
    
    return { 
      days, 
      monthName: start.format('MMMM'), 
      year: start.format('YYYY'),
      month: start.format('MM')
    }
  }, [currentGregorian])

  const navigateMonth = (direction: 'prev' | 'next') => {
    setCurrentJalali(next => next.clone().add(direction === 'prev' ? 1 : -1, 'jmonth'))
    setCurrentGregorian(next => next.clone().add(direction === 'prev' ? 1 : -1, 'month'))
  }

  const goToToday = () => {
    const now = moment().clone()
    setSelectedDate(now)
    setCurrentJalali(now.clone().startOf('jMonth'))
    setCurrentGregorian(now.clone().startOf('month'))
  }

  const handleGregorianDateChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value
    if (value) {
      const date = moment(value)
      if (date.isValid()) {
        setSelectedDate(date)
        setCurrentJalali(date.clone().startOf('jMonth'))
        setCurrentGregorian(date.clone().startOf('month'))
      }
    }
  }

  const handleDayClick = (jalaliDay: number, gregorian: string) => {
    if (jalaliDay > 0 && gregorian) {
      const date = moment(gregorian)
      setSelectedDate(date)
      setCurrentJalali(date.clone().startOf('jMonth'))
      setCurrentGregorian(date.clone().startOf('month'))
    }
  }

  const handleDayClickGregorian = (day: number, jalali: string) => {
    if (day > 0 && jalali) {
      const date = moment(jalali, 'jYYYY-jMM-jDD')
      setSelectedDate(date)
      setCurrentJalali(date.clone().startOf('jMonth'))
      setCurrentGregorian(date.clone().startOf('month'))
    }
  }

  const isToday = (gregorian: string) => today.format('YYYY-MM-DD') === gregorian
  const isTodayGregorian = (day: number) => {
    const date = currentGregorian.clone().add(day - 1, 'days')
    return date.format('YYYY-MM-DD') === today.format('YYYY-MM-DD')
  }
  const isSelected = (gregorian: string) => selectedDate.format('YYYY-MM-DD') === gregorian
  const isSelectedGregorian = (day: number) => {
    const date = currentGregorian.clone().add(day - 1, 'days')
    return date.format('YYYY-MM-DD') === selectedDate.format('YYYY-MM-DD')
  }

  return (
    <div className="app">
      <header className="header">
        <h1>تقویم  | Calendar</h1>
        <br/>
      </header>

      <div className="calendar-container">
        {/* Persian Calendar */}
        <div className="calendar-card">
          <h2>تقویم فارسی</h2>
          <div className="persian-date-picker">
            <select
              className="date-select"
              value={selectedDate.format('jYYYY')}
              onChange={(e) => {
                const newDate = currentJalali.clone().jYear(parseInt(e.target.value))
                setSelectedDate(newDate)
                setCurrentJalali(newDate.startOf('jMonth'))
                setCurrentGregorian(newDate.clone().startOf('month'))
              }}
            >
              {Array.from({ length: 100 }, (_, i) => 1400 + i).map(year => (
                <option key={year} value={year}>{toPersianNumber(year)}</option>
              ))}
            </select>
            <select
              className="date-select"
              value={parseInt(selectedDate.format('jMM'))}
              onChange={(e) => {
                const newDate = currentJalali.clone().jMonth(parseInt(e.target.value) - 1)
                setSelectedDate(newDate)
                setCurrentJalali(newDate.startOf('jMonth'))
                setCurrentGregorian(newDate.clone().startOf('month'))
              }}
            >
              {Object.entries(persianMonths).map(([key, value], index) => (
                <option key={key} value={index + 1}>{value}</option>
              ))}
            </select>
            <select
              className="date-select"
              value={parseInt(selectedDate.format('jDD'))}
              onChange={(e) => {
                const newDate = currentJalali.clone().jDate(parseInt(e.target.value))
                setSelectedDate(newDate)
                setCurrentGregorian(newDate.clone().startOf('month'))
              }}
            >
              {Array.from({ length: 31 }, (_, i) => 1 + i).map(day => (
                <option key={day} value={day}>{toPersianNumber(day)}</option>
              ))}
            </select>
            <button className="nav-btn today-btn" onClick={goToToday} style={{ marginRight: '10px' }}>
              امروز
            </button>
          </div>
          <div className="calendar-header">
            <button className="nav-btn" onClick={() => navigateMonth('prev')}>→</button>
            <span className="month-year">{getPersianMonthName(jalaliCal.monthName)} {toPersianNumber(jalaliCal.year)}</span>
            <button className="nav-btn" onClick={() => navigateMonth('next')}>←</button>
          </div>
          <div className="weekdays">
            {persianWeekdays.map((day, i) => (
              <div key={i} className="weekday">{day}</div>
            ))}
          </div>
          <div className="days-grid">
            {jalaliCal.days.map((d, i) => (
              <div
                key={i}
                className={`day ${d.jalali === 0 ? 'empty' : ''} ${d.gregorian && isToday(d.gregorian) ? 'today' : ''} ${d.gregorian && isSelected(d.gregorian) ? 'selected' : ''}`}
                onClick={() => handleDayClick(d.jalali, d.gregorian)}
              >
                {d.jalali > 0 && (
                  <span className="day-number">
                    {toPersianNumber(d.jalali)}
                    {/* <small>{d.gregorianShort}</small> */}
                  </span>
                )}
              </div>
            ))}
          </div>
        </div>

        {/* Gregorian Calendar */}
        <div className="calendar-card">
          <h2>Gregorian Calendar</h2>
          <div className="date-picker-row">
            <input
              type="date"
              className="date-input"
              value={selectedDate.format('YYYY-MM-DD')}
              onChange={handleGregorianDateChange}
            />
            <button className="nav-btn today-btn" onClick={goToToday} style={{ marginRight: '10px' }}>
              Today
            </button>
          </div>
          <div className="calendar-header">
            <button className="nav-btn" onClick={() => navigateMonth('prev')}>→</button>
            <span className="month-year">{gregorianCal.monthName} {gregorianCal.year}</span>
            <button className="nav-btn" onClick={() => navigateMonth('next')}>←</button>
          </div>
          <div className="weekdays">
            {gregorianWeekdays.map((day, i) => (
              <div key={i} className="weekday">{day}</div>
            ))}
          </div>
          <div className="days-grid">
            {gregorianCal.days.map((d, i) => (
              <div
                key={i}
                className={`day gregorian-day ${d.day === 0 ? 'empty' : ''} ${d.day > 0 && isTodayGregorian(d.day) ? 'today' : ''} ${d.day > 0 && isSelectedGregorian(d.day) ? 'selected' : ''}`}
                onClick={() => handleDayClickGregorian(d.day, d.jalali)}
              >
                {d.day > 0 && (
                  <span className="day-number">
                    {d.day}
                    {/* <small>{toPersianNumber(d.jalaliShort)}</small> */}
                  </span>
                )}
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}

export default App
