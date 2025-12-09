# spec/helpers/pages_helper_spec.rb
require 'rails_helper'

RSpec.describe PagesHelper, type: :helper do
  describe '#journey_badge_label_and_class' do
    # FIX: Define the hash as a local variable here, or define the tests dynamically.
    # The simplest fix is to define the hash outside the loop but still inside the describe block.

    badge_cases = { # <-- Defined as a local variable (not `let`)
      evergreen:         [ "badge-warning", "Evergreen" ],
      all_time_favorite: [ "badge-success", "All-Time Favorite" ],
      new_obsession:     [ "badge-success", "New Obsession" ],
      fading_out:        [ "badge-danger", "Fading Out" ],
      short_term:        [ "badge-info", "Short-Term Crush" ]
    }

    # Test all the explicitly defined cases
    badge_cases.each do |input, expected_output|
      context "when passed the badge :#{input}" do
        # Now the 'it' blocks can see the input and expected_output
        it "returns the expected class and label for symbol :#{input}" do
          expect(helper.journey_badge_label_and_class(input)).to eq(expected_output)
        end

        it "returns the expected class and label for string '#{input}'" do
          expect(helper.journey_badge_label_and_class(input.to_s)).to eq(expected_output)
        end
      end
    end

    # The rest of your code remains the same...
    context 'when passed an unknown badge' do
      # ... (rest of the tests)
      let(:unknown_symbol) { :one_hit_wonder }
      let(:unknown_string) { 'onE_hIt_wONdEr' }

      it 'returns the default class and the humanized label for a symbol' do
        expected_output = [ "badge-secondary", "One hit wonder" ] # Corrected humanize expected output
        expect(helper.journey_badge_label_and_class(unknown_symbol)).to eq(expected_output)
      end

      it 'returns the default class and the humanized label for a string' do
        expected_output = [ "badge-secondary", unknown_string.humanize ]
        expect(helper.journey_badge_label_and_class(unknown_string)).to eq(expected_output)
      end
    end
  end
end
