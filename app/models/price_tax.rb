# == Schema Information
#
# Table name: price_taxes
#
#  id           :integer       not null, primary key
#  price_id     :integer       not null
#  tax_id       :integer       not null
#  amount       :decimal(16, 4 default(0.0), not null
#  created_at   :datetime      not null
#  updated_at   :datetime      not null
#  created_by   :integer       
#  updated_by   :integer       
#  lock_version :integer       default(0), not null
#  company_id   :integer       not null
#

class PriceTax < ActiveRecord::Base
  belongs_to :company
  belongs_to :price
  belongs_to :tax

  validates_presence_of :company_id
  attr_readonly :company_id

  def before_validation
    unless self.tax.nil?
      self.amount = self.tax.compute(self.price.amount)
    end
  end

  def after_save
    self.price.refresh
  end

end
