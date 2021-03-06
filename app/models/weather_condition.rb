class WeatherCondition < ActiveRecord::Base
  self.primary_key = "date"

  validates :date,
            :max_temperature_f,
            :mean_temperature_f,
            :min_temperature_f,
            :mean_humidity,
            :mean_visibility_miles,
            :mean_wind_speed_mph,
            :precipitation_inches,
            :zip_code,
            presence: true

  validates :zip_code, inclusion: { in: [94107]}

  validates :date, uniqueness: true

  has_many :trips, :foreign_key => :start_date

  def self.trips_on_days(day_range)
    day_range.joins(:trips).group(:date).count
  end

  def self.days_with_high_temp(degrees)
    where(max_temperature_f: [degrees..degrees + 9])
  end

  def self.days_with_precip_inches(inches)
    where(precipitation_inches: [inches..inches + 0.49])
  end

  def self.days_with_wind_speed(speed)
    where(mean_wind_speed_mph: [speed..speed + 3])
  end

  def self.days_with_visibility(miles)
    where(mean_visibility_miles: [miles..miles + 3])
  end

  def self.temperature_metrics(degrees = 10)
    range = metric_range_with_increments_of(:max_temperature_f, degrees)
    range.reduce({}) do |result, degrees|
      days = days_with_high_temp(degrees)
      trips = trips_on_days(days).values
      result["#{degrees}"] = ride_metrics(trips)
      result
    end
  end

  def self.precipitation_metrics(inches = 0.5)
    range = metric_range_with_increments_of(:precipitation_inches, inches)
    range.reduce({}) do |result, inches|
      days = days_with_precip_inches(inches)
      trips = trips_on_days(days).values
      result["#{inches}"] = ride_metrics(trips)
      result
    end
  end

  def self.wind_metrics(speed = 4)
    range = metric_range_with_increments_of(:mean_wind_speed_mph, speed)
    range.reduce({}) do |result, speed|
      days = days_with_wind_speed(speed)
      trips = trips_on_days(days).values
      result["#{speed}"] = ride_metrics(trips)
      result
    end
  end

  def self.visibility_metrics(miles = 4)
    range = metric_range_with_increments_of(:mean_visibility_miles, miles)
    range.reduce({}) do |result, miles|
      days               = days_with_visibility(miles)
      trips              = trips_on_days(days).values
      result["#{miles}"] = ride_metrics(trips)
      result
    end
  end

  def self.master_metrics
    metrics = {}
    metrics[:temperature]   = temperature_metrics
    metrics[:precipitation] = precipitation_metrics
    metrics[:wind]          = wind_metrics
    metrics[:visibility]    = visibility_metrics
    metrics
  end

  def self.average_rides(rides)
    return 0 if rides.count.zero?
    rides.reduce(:+).to_i / rides.count
  end

  def self.highest_rides(rides)
    rides.max.to_i
  end

  def self.lowest_rides(rides)
    rides.min.to_i
  end

  def self.ride_metrics(rides)
    metrics = {}
    metrics[:average_rides] = average_rides(rides)
    metrics[:lowest_rides]  = lowest_rides(rides)
    metrics[:highest_rides] = highest_rides(rides)
    metrics
  end

  def self.metric_range_with_increments_of(method, incrementer)
    lower = minimum(method.to_sym)
    upper = maximum(method.to_sym)
    lower = lower / incrementer * incrementer
    upper = upper / incrementer * incrementer
    (lower..upper).step(incrementer).to_a
  end

  def self.weather_on_day_with_highest_rides
    max       = trips_on_days(all).max_by { |day, rides| rides }
    day       = max.first
    rides     = max.last
    [find_by(date: day), rides]
  end

  def self.weather_on_day_with_lowest_rides
    min       = trips_on_days(all).min_by { |day, rides| rides }
    day       = min.first
    rides     = min.last
    [find_by(date: day), rides]
  end

end
