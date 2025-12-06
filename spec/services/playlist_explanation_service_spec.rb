require "rails_helper"

RSpec.describe PlaylistExplanationService do
  it "returns similar and different explanations" do
    service = described_class.new(
      vector_a: [ 0.8, 0.7, 0.6, 0.2, 0.1 ],
      vector_b: [ 0.82, 0.65, 0.58, 0.5, 0.3 ]
    )

    result = service.explanations

    expect(result).to be_present
    expect(result.first).to include("aligned on")
    expect(result.last).to include("leans more on")
  end

  it "returns empty when vectors are missing" do
    expect(described_class.new(vector_a: nil, vector_b: [ 1 ]).explanations).to eq([])
  end
end
