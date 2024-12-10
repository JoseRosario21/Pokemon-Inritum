module Enumerable
  alias has? include?
  alias includes? include?
  alias contains? include?

  def remove(*items)
    items.flatten!
    items.each { |item| delete(item) }
  end
end