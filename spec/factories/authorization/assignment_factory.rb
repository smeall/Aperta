FactoryGirl.define do
  factory :assignment do
    role
    user
  end

  trait :assigned_to_task do
    association :assigned_to, factory: :ad_hoc_task
  end
end
