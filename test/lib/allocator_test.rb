# frozen_string_literal: true
require_relative '../test_helper'

describe GlobalUid::Allocator do
  let(:connection)   { mock('connection') }
  let(:increment_by) { 10 }
  let(:allocator)    { GlobalUid::Allocator.new(incrementing_by: increment_by, connection: connection) }
  let(:table)        { mock('table_class').class }

  before do
    restore_defaults!
    connection.stubs(:current_database).returns('database_name')
  end

  describe 'with a configured increment_by that differs from the connections auto_increment_increment' do
    it 'raises an exception to prevent erroneous ID allocation' do
      connection.stubs(:select_value).with('SELECT @@auto_increment_increment').returns(50)
      exception = assert_raises(GlobalUid::InvalidIncrementException) do
        GlobalUid::Allocator.new(incrementing_by: 10, connection: connection)
      end

      assert_equal("Configured: '10', Found: '50' on 'database_name'", exception.message)
    end
  end

  describe 'with a configured increment_by that matches the connections auto_increment_increment' do
    before do
      connection.stubs(:select_value).with('SELECT @@auto_increment_increment').returns(increment_by)
    end

    describe '#allocate_one' do
      it 'allocates IDs, maintaining a small rolling selection of IDs for comparison' do
        [10, 20, 30, 40, 50, 60, 70, 80].each do |id|
          connection.expects(:insert).returns(id)
          allocator.allocate_one(table)
        end

        assert_equal(5, allocator.max_window_size)
        assert_equal([40, 50, 60, 70, 80], allocator.recent_allocations)
      end

      describe 'gap between ID not divisible by increment_by' do
        it 'raises an error' do
          connection.expects(:insert).returns(20)
          allocator.allocate_one(table)

          connection.stubs(:select_value).with('SELECT @@auto_increment_increment').returns(5)
          connection.expects(:insert).returns(25)
          exception = assert_raises(GlobalUid::InvalidIncrementException) do
            allocator.allocate_one(table)
          end

          assert_equal("Configured: '10', Found: '5' on 'database_name'. Recently allocated IDs: [20, 25]", exception.message)
        end
      end

      describe 'ID value does not increment upwards' do
        it 'raises an error' do
          connection.expects(:insert).returns(20)
          allocator.allocate_one(table)

          connection.expects(:insert).returns(20 - increment_by)
          exception = assert_raises(GlobalUid::InvalidIncrementException) do
            allocator.allocate_one(table)
          end

          assert_equal("Configured: '10', Found: '10' on 'database_name'. Recently allocated IDs: [20, 10]", exception.message)
        end
      end
    end

    describe '#allocate_many' do
      it 'allocates IDs, maintaining a small rolling selection of IDs for comparison' do
        connection.expects(:insert)
          .with("REPLACE INTO Mocha::Mock (stub) VALUES ('a'),('a'),('a'),('a'),('a'),('a'),('a'),('a')")
          .returns(10)
        allocator.allocate_many(table, count: 8)

        assert_equal(5, allocator.max_window_size)
        assert_equal([40, 50, 60, 70, 80], allocator.recent_allocations)
      end

      describe 'with a configured increment_by that differs from the active connection auto_increment_increment' do
        it 'raises an error' do
          connection.stubs(:select_value).with('SELECT @@auto_increment_increment').returns(5)
          connection.expects(:insert).never
          exception = assert_raises(GlobalUid::InvalidIncrementException) do
            allocator.allocate_many(table, count: 8)
          end

          assert_equal("Configured: '10', Found: '5' on 'database_name'", exception.message)
        end
      end
    end
  end
end
