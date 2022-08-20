require_relative 'date_nav'

RSpec.describe DateNav do
  describe '#prev_hits' do
    subject do
      described_class.new(reference_date, sorted_available_dates)
    end

    let(:reference_date) { Date.new(1962, 1, 3) }

    context 'with all date available' do
      let(:sorted_available_dates) do
        [
          Date.new(1961,  1,  3),
          Date.new(1961, 12,  3),
          Date.new(1961, 12, 27),
          Date.new(1962,  1,  1)
        ]
      end

      it 'finds direct hits on all dates' do
        expect(subject.prev_hits).to eq(
          [
            [:year,  Date.new(1961,  1,  3)],
            [:month, Date.new(1961, 12,  3)],
            [:week,  Date.new(1961, 12, 27)],
            [:prev,  Date.new(1962,  1,  1)]
          ]
        )
      end
    end

    context 'with prev date a week ago' do
      let(:sorted_available_dates) do
        [
          Date.new(1961,  1,  3),
          Date.new(1961, 12,  3),
          Date.new(1961, 12, 27)
        ]
      end

      it 'skips prev week' do
        expect(subject.prev_hits).to eq(
          [
            [:year,  Date.new(1961,  1,  3)],
            [:month, Date.new(1961, 12,  3)],
            [:prev,  Date.new(1961, 12, 27)]
          ]
        )
      end
    end

    context 'with no previous dates' do
      let(:sorted_available_dates) do
        [Date.new(1972, 1, 1), Date.new(2000, 1, 1)]
      end

      it 'returns nil' do
        expect(subject.prev_date).to eq(nil)
      end
    end
  end
end
