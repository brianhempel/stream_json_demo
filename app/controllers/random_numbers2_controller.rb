class RandomNumbers2Controller < ApplicationController
  include ActionController::Live

  def index
    headers["Content-Type"]        = "application/json"
    lazy_enum = random_number_objects_lazy.take(10)

    lazy_enum.each_with_index do |object, i|
      response.stream.write(JSON.dump(object) + "\n")
      sleep 0.5
    end

    response.stream.close
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
end
