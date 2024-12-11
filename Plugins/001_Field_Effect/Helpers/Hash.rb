class Hash
  def number?
    false
  end

  def choose(*keys)
    items.flatten!
    select { |key, _value| keys.has?(key) }
  end

  def set_values(new_value)
    transform_values { new_value }
  end

  def set_values!(new_value)
    transform_values! { new_value }
  end

  def sorted_keys
    sort_by { |_key, value| value }.map(&:first)
  end

  def sorted_keys_reverse
    sort_by { |_key, value| -value }.map(&:first)
  end

  def sorted_values
    values.sort
  end

  def sorted_values_reverse
    values.sort.reverse
  end

  def highest_keys
    select { |_key, value| value == highest_value }.keys
  end

  def highest_value
    values.max
  end

  def lowest_keys
    select { |_key, value| value == lowest_value }.keys
  end

  def lowest_value
    values.min
  end
end