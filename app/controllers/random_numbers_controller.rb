class RandomNumbersController < ApplicationController
  include ActionController::Live

  # Return a million random numbers.
  NUMBERS_COUNT = 1_000_000

  # Write out to client after every 2000 objects.
  FLUSH_EVERY = 2_000

  def index
    lazy_enum = random_number_objects_lazy.take(NUMBERS_COUNT)

    stream_json_array(lazy_enum)
  end

  private

  def random_numbers_lazy
    (0..Float::INFINITY).lazy.map { SecureRandom.random_number(2**128) }
  end

  def random_number_objects_lazy
    random_numbers_lazy.each_with_index.map do |random_number, i|
      {
        index:  i,
        time:   Time.current.xmlschema(3),
        number: random_number
      }
    end
  end

  # Note that chunked deflate seems not to work in curl. (Chunked plain JSON is fine.)
  # Chunked deflate works in Chrome.
  def stream_json_array(enum)
    headers["Content-Disposition"] = "attachment" # Download response to file. It's big.
    headers["Content-Type"]        = "application/json"
    headers["Content-Encoding"]    = "deflate"

    deflate = Zlib::Deflate.new

    buffer = "[\n  "
    enum.each_with_index do |object, i|
      buffer << ",\n  " unless i == 0
      buffer << JSON.pretty_generate(object, depth: 1)

      if i % FLUSH_EVERY == 0
        write(deflate, buffer)
        buffer = ""
      end
    end
    buffer << "\n]\n"

    write(deflate, buffer)
    write(deflate, nil) # Flush deflate.
    response.stream.close
  end

  def write(deflate, data)
    deflated = deflate.deflate(data)
    response.stream.write(deflated)
  end
end
