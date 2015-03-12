# Stream JSON Demo

You can see the [entire diff compared to a vanilla Rails 4.2.0 app](https://github.com/brianhempel/stream_json_demo/commit/6bd580ea9bf3b1d508bb1ce9e48834bf67e313df).

The app lazily generates a million random numbers and streams json to the client at the `/random_numbers` endpoint:

```http
HTTP/1.1 200 OK
Content-Type: application/json
Content-Encoding: deflate
Transfer-Encoding: chunked
```
```json
[
  {
    "index": 0,
    "time": "2015-03-12T16:24:59.381Z",
    "number": 96712233280936019238290948377812066522
  },
  {
    "index": 1,
    "time": "2015-03-12T16:24:59.381Z",
    "number": 322627977204921440486826283319053625299
  },
  {
    "index": 2,
    "time": "2015-03-12T16:24:59.381Z",
    "number": 174374410324316249417283007292339235935
  }
]
```

To stream the JSON, the app uses [`ActionController::Live`](http://tenderlovemaking.com/2012/07/30/is-it-live.html) which allows us to send data to the client in chunks with [HTTP chunked transfer encoding](http://en.wikipedia.org/wiki/Chunked_transfer_encoding). The action also demonstrates compressing such a response with [deflate](http://en.wikipedia.org/wiki/HTTP_compression). With this setup, you could (theoretically) stream an infinitely large response to the client without running out of memory.

The relevant file is [`app/controllers/random_numbers_controller.rb`](https://github.com/brianhempel/stream_json_demo/blob/master/app/controllers/random_numbers_controller.rb):

```ruby
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
```