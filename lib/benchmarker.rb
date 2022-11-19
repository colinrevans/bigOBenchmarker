# typed: false
# frozen_string_literal: true

# EMPIRICAL BENCHMARKING FOR BIG O NOTATION

require "benchmark"
require "progress_bar"
require "colorize"
require "byebug"

# float formatting
def ff(float)
  format("%.15f", float).sub(/0+$/, "").sub(/\.$/, ".0")
end

# float array formatting
def fa(arr)
  ret = "["
  arr.each do |elem|
    ret += "+" if elem > 0
    ret += ff(elem)
    ret += ", "
  end
  ret = ret[0...-2]
  ret += "]"
  ret
end

class OrderBenchmarker
  attr_accessor :inputs,
    :benchmark_times,
    :data_creation_proc,
    :input_size_function,
    :timeout,
    :results

  def initialize(
    inputs = (1..1000).to_a,
    benchmark_times = 5,
    data_creation_proc = proc { |x| x },
    input_size_function = proc { |x| x + 1 },
    timeout = nil
  )
    @name = ""
    @inputs = inputs
    @benchmark_times = benchmark_times
    @data_creation_proc = data_creation_proc
    @input_size_function = input_size_function
    @timeout = timeout
    @results = []
    @lowers = []
    @analyze_singles = false
    @proc_to_measure = proc { |x| x }
    @time_taken_for_first = nil

    # ORDER MATTERS
    @o_functions = {
      "1" => ->(_) { 1 },
      "lg(lg(n))" => ->(n) { Math.log2(Math.log2(n)) },
      "lg(n)" => ->(n) { Math.log2(n) },
      "n" => ->(n) { n },
      "nlg(n)" => ->(n) { n * Math.log2(n) },
      "n**2" => ->(n) { n**2 },
      # "n**2lg(n)" => ->(n) { n**2 * Math.log2(n) },
      "n**3" => ->(n) { n**3 },
      "2**n" => ->(n) { 2**n },
    }
  end

  def benchmark(proc_to_measure, inputs = @inputs)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    bar = ProgressBar.new(@inputs.length)
    (@inputs.length - inputs.length).times { bar.increment! }

    results = []
    interrupted = false

    # if it's a first run, find how long f(1) takes.
    @time_taken_for_first = nil if inputs.length == @inputs.length
    last_i = nil

    begin
      inputs.each_with_index do |input, i|
        cur_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        if !@timeout.nil? && cur_time - start_time > @timeout
          puts "timeout for input length #{inputs.length}. completed n=#{i}".red
          break
        end

        data = @data_creation_proc.call(input)
        time_taken =
          Benchmark.realtime do
            @benchmark_times.times { proc_to_measure.call(data) }
          end

        @time_taken_for_first = time_taken if @time_taken_for_first.nil?
        # CURRENT TODO: map over functions instead.
        data =
          @o_functions.map do |k, v|
            compare_g_of_n(
              @input_size_function.call(i + @results.length),
              @time_taken_for_first,
              time_taken,
              k,
              v,
            )
          end
        results << data
        bar.increment!
        last_i = i
      end
    rescue Interrupt
      interrupted = true
      puts ""
      puts "moving on".red
    end

    @results += results
    !interrupted
  end

  def inexact
    @benchmark_times = 5
    self
  end

  def exact
    @benchmark_times = 100
    self
  end

  def benchmarking(&block)
    @proc_to_measure = block
    self
  end

  def creating_inputs_with(&block)
    @data_creation_proc = block
    self
  end

  def named(name)
    @name = name
    self
  end

  def with_n_range(inputs)
    @inputs = inputs.to_a
    self
  end

  def with_timeout(tm)
    @timeout = timeout
    self
  end

  def with_n_up_to(peak)
    raise if peak < 1

    @inputs = (1..peak).to_a
    self
  end

  def benchmark_and_print(
    name = @name,
    proc_to_measure = @proc_to_measure,
    table = false
  )
    @name = name
    puts ""
    puts ("-" * name.length).yellow
    puts name.upcase.yellow
    puts ("-" * name.length).yellow
    puts ""
    puts "  running benchmarks ... "

    interrupted = true

    while interrupted
      interrupted = !benchmark(proc_to_measure, @inputs[0 + @results.length..])

      lasts =
        @o_functions.each_key.each_with_index.map do |_, i|
          analyses = analyze_ratios(@results.map { |arr| arr[i] })
          analysis = analyses[-1]
        end

      last_omega = 0
      first_o = lasts.length - 1
      # iterates from most expensive function down to cheapest.
      lasts.each_with_index do |analysis, i|
        last_omega = i if analysis["kind"] == "omega"
        if analysis["kind"] == "little o"
          first_o = i
          break
        end
      end

      lasts = lasts[last_omega..first_o]
      lasts.reverse_each { |analysis| print_analysis(analysis) }

      thetas_string =
        lasts
          .select { |analysis| analysis["kind"] == "theta" }
          .map { |analysis| analysis["fn_name"] }
          .join(", ")
          .yellow + " possibly theta for #{@name.yellow}"

      puts (" " * 20) + "|-" + "-" * (thetas_string.length - 28) + "-|"
      puts (" " * 20) + "| " + thetas_string + " |"
      puts (" " * 20) + "|-" + "-" * (thetas_string.length - 28) + "-|"
      puts ""

      next unless interrupted

      puts "continue benchmarking #{@name.yellow}? (y/n)"
      answer = gets.chomp
      interrupted = false if answer == "n"
    end
    puts ""
    self
  end

  def analyzer
    puts ""
    puts "ANALYZER: enter input size."
    while true
      num = gets.chomp
      break if num == "q"

      begin
        index = num.to_i - 1
        next if index < 0

        puts results[index]
      rescue StandardError => e
        p(e)
        next
      end
    end
  end

  def compare_g_of_n(input_size, scalar, time_taken, g_of_n_name, g_of_n_proc)
    expected_time = g_of_n_proc.call(input_size) * scalar
    {
      name: g_of_n_name,
      input_size: input_size,
      expected_time: expected_time,
      ratio: expected_time / time_taken,
      inverse_ratio: time_taken / expected_time,
      time_taken: time_taken,
    }
  end

  def print_analysis(analysis)
    puts "  #{analysis["fn_name"]}".green
    puts ""
    puts "     over last #{analysis["size"].to_s.yellow} input sizes in range #{analysis["range"].to_s.yellow}"
    puts ""
    puts ""
    puts "     quartile average        g(n)/f(n)  : #{fa(analysis["quartile_average"])}"
    puts "     quartile average  d/dx[ g(n)/f(n) ]: #{fa(analysis["slope_quartiles"])}"
    puts ""
    puts "     last 50 average         g(n)/f(n)  : #{ff(analysis["last_50_average"])}"
    puts "     last 50 average   d/dx[ g(n)/f(n) ]: #{ff(analysis["last_50_average_slope"])}"
    puts ""
    case analysis["kind"]
    when "omega"
      puts "          f(n) = ω( #{analysis["fn_name"]} )?".blue +
        " g(n)/f(n) likely approaches 0 as n -> infinity."
    when "theta"
      puts "          f(n) = θ( #{analysis["fn_name"]} )?".green +
        " g(n)/f(n) likely approaches nonzero constant as n -> infinity."
    when "little o"
      puts "          f(n) = o( #{analysis["fn_name"]} )?".red +
        " g(n)/f(n) likely approaches positive infinity as n -> infinity."
    end
    puts ""
  end

  def analyze_ratios(results, only_last = false)
    ratios = [{ name: results[0][:name], ratios: [] }]
    analyses = []
    results.each do |res|
      if res[:name] == ratios[-1][:name]
        ratios[-1][:ratios] << res[:ratio]
      else
        ratios << { name: res[:name], ratios: [res[:ratio]] }
      end
    end
    seen = 1
    theta = nil
    ratios.each_with_index do |ratio_dict, idx|
      next if only_last && idx < ratios.length - 1

      ratio_arr = ratio_dict[:ratios]
      fn_name = ratio_dict[:name]

      next if ratio_arr.length == 1 && !@analyze_singles

      size = ratio_arr.length
      range = (results.length - ratio_arr.length + 1..results.length)

      seen += ratio_arr.length
      delta = ratio_arr.reduce(ratio_arr[0]) { |acc, cur| cur - acc }
      deltas =
        (1..ratio_arr.length - 1).map { |i| ratio_arr[i] - ratio_arr[i - 1] }

      slope_quartiles = average_across_quarters(deltas[deltas.length / 2..])
      quartile_average =
        average_across_quarters(ratio_arr[ratio_arr.length / 2..])
      last_50_average = ratio_arr[-[50, ratio_arr.length].min..].sum / 50.0
      last_50_average_slope = deltas[-[50, deltas.length].min..].sum / 50.0
      ratio_quartile_delta =
        average_across_quarters(deltas)[-1] -
        average_across_quarters(deltas)[-2]

      slope_quartile_abs = slope_quartiles.map { |q| q.abs }

      limiting_to_a_value =
        slope_quartile_abs[-2] > slope_quartile_abs[-1] ||
        slope_quartile_abs[2..].all? { |x| x < 0.05 }

      going_to_zero =
        average_across_quarters(ratio_arr)[3..].all? { |x| x < 1 } &&
        (
          slope_quartiles[2..].all? { |q| q < 0 } ||
            slope_quartiles.all? { |q| q.abs < 0.000005 }
        )

      kind = ""
      kind = if limiting_to_a_value
        if going_to_zero
          "omega"
        else
          "theta"
        end
      else
        "little o"
      end

      analyses << {
        "fn_name" => fn_name,
        "kind" => kind,
        "slope_quartiles" => slope_quartiles,
        "quartile_average" => quartile_average,
        "last_50_average" => last_50_average,
        "last_50_average_slope" => last_50_average_slope,
        "range" => range,
        "size" => size,
      }
    end

    puts ""
    # prev = nil
    # ratios.each do |ratio_dict|
    #   if (ratio_dict[:ratios].length == 1 && !@analyze_singles) ||
    #        ratio_dict[:name] == prev
    #     next
    #   end
    #   prev = ratio_dict[:name]
    #   print ratio_dict[:name].yellow + " -> ".yellow
    # end
    # print "?\n".yellow
    analyses
  end
end

def median(arr)
  return arr[arr.length / 2] if arr.length.odd?

  (arr[arr.length / 2 - 1] + arr[arr.length / 2]) / 2
end

def average_across_quarters(arr)
  j, k, l = 0, arr.length / 4, arr.length / 2, arr.length * (3 / 4)
  sum = ->(arr) { arr.reduce(0) { |acc, cur| acc + cur } }
  first_quart = sum.call(arr[0..j]) / arr[0..j].length
  second_quart = sum.call(arr[j..k]) / arr[j..k].length
  third_quart = sum.call(arr[k..l]) / arr[k..l].length
  fourth_quart = sum.call(arr[l..]) / arr[l..].length

  [first_quart, second_quart, third_quart, fourth_quart]
end
