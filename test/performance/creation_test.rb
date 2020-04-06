# frozen_string_literal: true
require_relative '../test_helper'

describe GlobalUid do
  before do
    Phenix.rise!(with_schema: false)
    ActiveRecord::Base.establish_connection(:test)
    reset_connections!
    restore_defaults!
  end

  after do
    Phenix.burn!
  end

  describe "Performance" do
    before do
      CreateWithNoParams.up
      CreateWithoutGlobalUIDs.up
    end

    it "has a negligible performance impact" do
      report = Benchmark.ips do |x|

        x.report(WithGlobalUID)    { WithGlobalUID.create! }
        x.report(WithoutGlobalUID) { WithoutGlobalUID.create! }


        x.compare!
      end

      with_global_uid    = report.entries.find { |e| e.label == WithGlobalUID }.stats
      without_global_uid = report.entries.find { |e| e.label == WithoutGlobalUID }.stats

      performance_impact, _ = with_global_uid.slowdown(without_global_uid)
      # assert_operator performance_impact, :<, 1.45
    end

    after do
      reset_connections!
      CreateWithNoParams.down
      CreateWithoutGlobalUIDs.down
    end
  end
end
