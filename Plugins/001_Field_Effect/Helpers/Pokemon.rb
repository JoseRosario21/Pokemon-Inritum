class Pokemon
  def regenerate_unique_id(digits = 8)
    @unique_id = generate_unique_id(digits)
  end

  def unique_id
    @unique_id ||= generate_unique_id
  end
end

def generate_unique_id(digits = 8)
  random_ints = ("0".."9").to_a.sample(digits)
  random_letters = ("a".."z").to_a.sample(digits) + ("A".."Z").to_a.sample(digits)
  (random_ints + random_letters).shuffle!.join
end