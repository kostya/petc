module Myc::Stats
  def debug(subsystem, &)
    {% if !flag?(:release) %}
      if ENV["DEBUG"]? == "1"
        yield
      end
    {% end %}
  end

  TIMES = Hash(String, Float64).new(0.0)

  def measure(name, &)
    name = name.to_s
    t = Time.instant
    res = yield
    delta = (Time.instant - t).to_f
    if t = TIMES[name]?
      TIMES[name] = t + delta
    else
      TIMES[name] = delta
    end

    res
  end

  def print_timers
    if ENV["MYC_TIMERS"]? == "1"
      STDOUT << "{"
      TIMES.each_with_index do |(k, v), i|
        STDOUT << ", " if i != 0
        STDOUT << "\"#{k}\": %.7f" % {v}
      end
      STDOUT << "}"
    end
  end
end
