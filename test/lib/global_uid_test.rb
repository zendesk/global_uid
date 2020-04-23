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

  describe "#global_uid_disabled" do
    before do
      [ Parent, ParentSubclass, ParentSubclassSubclass ].each { |k| k.reset }
    end

    it "default to the parent value or false" do
      assert !ParentSubclass.global_uid_disabled

      ParentSubclass.disable_global_uid
      assert ParentSubclass.global_uid_disabled
      assert ParentSubclassSubclass.global_uid_disabled

      ParentSubclass.reset
      assert !ParentSubclass.global_uid_disabled
      assert ParentSubclassSubclass.global_uid_disabled

      ParentSubclassSubclass.reset
      assert !ParentSubclass.global_uid_disabled
      assert !ParentSubclassSubclass.global_uid_disabled
    end

    it "uses the default AUTO_INCREMENT, skipping the alloc servers" do
      CreateWithoutGlobalUIDs.up
      GlobalUid::Base.expects(:get_uid_for_class).never

      (1..10).each do |index|
        assert_equal index, WithoutGlobalUID.create!.id
      end

      CreateWithoutGlobalUIDs.down
    end
  end

  describe "migrations" do
    def table_exists?(connection, table)
      if ActiveRecord::VERSION::MAJOR >= 5
        connection.data_source_exists?(table)
      else
        connection.table_exists?(table)
      end
    end

    describe "without explicit parameters" do
      describe "with global-uid enabled" do
        before do
          GlobalUid::Base.global_uid_options[:storage_engine] = "InnoDB"
          CreateWithNoParams.up
          @create_table = show_create_sql(WithGlobalUID, "with_global_uids").split("\n")
        end

        it "create the global_uids table" do
          GlobalUid::Base.with_connections do |connection|
            assert table_exists?(connection, 'with_global_uids_ids'), 'Table should exist'
          end
        end

        it "create global_uids tables with matching ids" do
          GlobalUid::Base.with_connections do |connection|
            foo = connection.select_all("select id from with_global_uids_ids")
            assert_equal(foo.first['id'].to_i, 1)
          end
        end

        it "create tables with the given storage_engine" do
          GlobalUid::Base.with_connections do |connection|
            foo = connection.select_all("show create table with_global_uids_ids")
            assert_match(/ENGINE=InnoDB/, foo.first.values.join)
          end
        end

        it "tear off the auto_increment part of the primary key from the created table" do
          id_line = @create_table.grep(/\`id\` int/i).first
          refute_match(/auto_increment/i, id_line)
        end

        it "create a primary key on id" do
          refute_empty @create_table.grep(/primary key/i)
        end

        after do
          CreateWithNoParams.down
        end
      end

      describe "dropping a table" do
        it "not drop the global-uid tables" do
          CreateWithNoParams.up
          GlobalUid::Base.with_connections do |connection|
            assert table_exists?(connection, 'with_global_uids_ids'), 'Table should exist'
          end

          CreateWithNoParams.down
          GlobalUid::Base.with_connections do |connection|
            assert table_exists?(connection, 'with_global_uids_ids'), 'Table should be dropped'
          end
        end
      end

      describe "with global-uid disabled, globally" do
        before do
          GlobalUid::Base.global_uid_options[:disabled] = true
          CreateWithNoParams.up
        end

        it "not create the global_uids table" do
          GlobalUid::Base.with_connections do |connection|
            assert !table_exists?(connection, 'with_global_uids_ids'), 'Table should not have been created'
          end
        end

        after do
          CreateWithNoParams.down
        end
      end
    end

    describe "with :use_global_uid => true" do
      describe "dropping a table" do
        it "drop the global-uid tables" do
          CreateWithExplicitUidTrue.up
          GlobalUid::Base.with_connections do |connection|
            assert table_exists?(connection, 'with_global_uids_ids'), 'Table should exist'
          end

          CreateWithExplicitUidTrue.down
          GlobalUid::Base.with_connections do |connection|
            assert !table_exists?(connection, 'with_global_uids_ids'), 'Table should be dropped'
          end
        end
      end
    end

    describe "with global-uid disabled in the migration" do
      before do
        CreateWithoutGlobalUIDs.up
        @create_table = show_create_sql(WithoutGlobalUID, "without_global_uids").split("\n")
      end

      it "not create the global_uids table" do
        GlobalUid::Base.with_connections do |connection|
          assert !table_exists?(connection, 'without_global_uids_ids'), 'Table should not not have been created'
        end
      end

      it "create standard auto-increment tables" do
        id_line = @create_table.grep(/.id. (big)?int/i).first
        assert_match(/auto_increment/i, id_line)
      end

      after do
        CreateWithoutGlobalUIDs.down
      end
    end

    describe "schema dumping" do
      before do
        CreateWithoutGlobalUIDs.up
        CreateWithNoParams.up
      end

      it "set global_uid flags as appropriate" do
        stream = StringIO.new
        ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
        stream.rewind
        schema = stream.read

        with_line = schema.split("\n").grep(/with_global_uids/).first
        assert_match(/use_global_uid: true/, with_line)

        without_line = schema.split("\n").grep(/without_global_uids/).first
        assert_match(/use_global_uid: false/, without_line)
      end

      after do
        CreateWithoutGlobalUIDs.down
        CreateWithNoParams.down
      end
    end

    describe "has_and_belongs_to_many associations" do
      it "inherits global_uid_disabled from the left-hand-side of the association" do
        assert Account.const_get(:HABTM_People).global_uid_disabled
        refute Person.const_get(:HABTM_Account).global_uid_disabled
      end
    end
  end

  describe "With InnoDB engine" do
    before do
      GlobalUid::Base.global_uid_options[:storage_engine] = "InnoDB"
      CreateWithNoParams.up
      CreateWithoutGlobalUIDs.up
    end

    after do
      reset_connections!
      CreateWithNoParams.down
      CreateWithoutGlobalUIDs.down
    end
  end

  describe "Updating the auto_increment_increment on active alloc servers" do
    before do
      CreateWithNoParams.up
      CreateWithoutGlobalUIDs.up

      @notifications = []
      GlobalUid::Base.global_uid_options[:notifier] = Proc.new do |exception, message|
        GlobalUid::Base::GLOBAL_UID_DEFAULTS[:notifier].call(exception, message)
        @notifications << exception.class
      end
    end

    describe 'with increment exceptions raised' do
      it 'takes the servers out of the pool, preventing usage during update' do
        assert_raises(GlobalUid::NoServersAvailableException) do
          # Double the increment_by value and set it on the database connection (auto_increment_increment)
          # Record creation will fail as all connections will be rejected since they're configured incorrectly.
          # The client is expecting `auto_increment_increment` to equal the configured `increment_by`
          with_modified_connections(increment: 10, servers: ["test_id_server_1", "test_id_server_2"]) do
            25.times { WithGlobalUID.create! }
          end
        end
      end
    end

    describe "with increment exceptions suppressed " do
      before do
        GlobalUid::Base.global_uid_options[:suppress_increment_exceptions] = true
      end

      it "allows the increment to be updated" do
        # Prefill alloc servers with a few records, initializing a connection to both alloc servers
        test_unique_ids(25)
        assert_empty(@notifications)

        # Update the active `test_id_server_1` connection, setting a `auto_increment_increment`
        # value that differs to what's configured and expected
        # The change should be noted and record creation should continue on both servers
        with_modified_connections(increment: 10, servers: ["test_id_server_1"]) do
          test_unique_ids(25)
          assert_includes(@notifications, GlobalUid::InvalidIncrementException)
          assert_equal(2, GlobalUid::Base.connections.length)
        end

        # Update both active `test_id_server_1` and `test_id_server_2` connections, setting a `auto_increment_increment`
        # value that differs to what's configured and expected
        # The change should be noted and record creation should continue on both servers
        @notifications = []
        with_modified_connections(increment: 10, servers: ["test_id_server_1", "test_id_server_2"]) do
          test_unique_ids(25)
          assert_includes(@notifications, GlobalUid::InvalidIncrementException)
          assert_equal(2, GlobalUid::Base.connections.length)
        end
      end
    end

    after do
      reset_connections!
      CreateWithNoParams.down
      CreateWithoutGlobalUIDs.down
    end
  end

  describe "With GlobalUID" do
    before do
      CreateWithNoParams.up
      CreateWithoutGlobalUIDs.up
    end

    describe "normally" do
      it "create tables with the default MyISAM storage engine" do
        GlobalUid::Base.with_connections do |connection|
          foo = connection.select_all("show create table with_global_uids_ids")
          assert_match(/ENGINE=MyISAM/, foo.first.values.join)
        end
      end

      it "get a unique id" do
        test_unique_ids
      end

      describe 'when the auto_increment_increment changes' do
        before do
          @notifications = []
          GlobalUid::Base.global_uid_options[:notifier] = Proc.new do |exception, message|
            GlobalUid::Base::GLOBAL_UID_DEFAULTS[:notifier].call(exception, message)
            @notifications << exception.class
          end
        end

        describe "and all servers report a value other than what's configured" do
          it "raises an exception when configuration incorrect during initialization" do
            GlobalUid::Base.global_uid_options[:increment_by] = 42
            reset_connections!
            assert_raises(GlobalUid::NoServersAvailableException) { test_unique_ids(10) }
            assert_includes(@notifications, GlobalUid::InvalidIncrementException)
          end

          it "raises an exception, preventing duplicate ID generation" do
            GlobalUid::Base.with_connections do |con|
              con.execute("SET SESSION auto_increment_increment = 42")
            end

            assert_raises(GlobalUid::NoServersAvailableException) { test_unique_ids(10) }
            assert_includes(@notifications, GlobalUid::InvalidIncrementException)
          end

          it "raises an exception before attempting to generate many UIDs" do
            GlobalUid::Base.with_connections do |con|
              con.execute("SET SESSION auto_increment_increment = 42")
            end

            assert_raises GlobalUid::NoServersAvailableException do
              WithGlobalUID.generate_many_uids(10)
            end
            assert_includes(@notifications, GlobalUid::InvalidIncrementException)
          end

          it "doesn't cater for increment_by being increased by a factor of x" do
            GlobalUid::Base.with_connections do |connection|
              connection.execute("SET SESSION auto_increment_increment = #{GlobalUid::Base::GLOBAL_UID_DEFAULTS[:increment_by] * 2}")
            end
            # Due to multiple processes and threads sharing the same alloc server, identifiers may be provisioned
            # before the current thread receives its next one. We rely on the gap being divisible by the configured increment
            test_unique_ids(10)
            assert_empty(@notifications)
          end
        end

        describe "and only one server reports a value other than what's configured" do
          it "notifies the client when configuration incorrect during initialization" do
            with_modified_connections(increment: 42, servers: ["test_id_server_1"]) do

              # Trigger the exception, one call may not hit the server, there's still a 1/(2^32) chance of failure.
              test_unique_ids(32)
              assert_includes(@notifications, GlobalUid::InvalidIncrementException)
            end
          end

          it "notifies the client and continues with the other connection" do
            con = GlobalUid::Base.connections.first
            con.execute("SET SESSION auto_increment_increment = 42")

            # Trigger the exception, one call may not hit the server, there's still a 1/(2^32) chance of failure.
            test_unique_ids(32)
            assert_includes(@notifications, GlobalUid::InvalidIncrementException)
          end

          it "notifies the client and continues when attempting to generate many UIDs" do
            con = GlobalUid::Base.connections.first
            con.execute("SET SESSION auto_increment_increment = 42")

            # Trigger the exception, one call may not hit the server, there's still a 1/(2^32) chance of failure.
            32.times { WithGlobalUID.generate_many_uids(10) }
            assert_includes(@notifications, GlobalUid::InvalidIncrementException)
          end
        end
      end
    end

    describe "With a timing out server" do
      def with_timed_out_connection(server:, end_time:)
        modified_connection = lambda do |config|
          if config["database"].include?(server)
            raise GlobalUid::ConnectionTimeoutException if end_time > Time.now
          end

          ActiveRecord::Base.__minitest_stub__mysql2_connection(config)
        end
        ActiveRecord::Base.stub :mysql2_connection, modified_connection do
          reset_connections!
          yield
        end
      end

      it "limp along with one functioning server" do
        with_timed_out_connection(server: "test_id_server_1", end_time: Time.now + 10.minutes) do
          test_unique_ids(10)
          assert_equal 1, GlobalUid::Base.connections.size
          assert_equal 'global_uid_test_id_server_2', GlobalUid::Base.connections[0].current_database
        end
      end

      it "eventually retry the connection and get it back in place" do
        with_timed_out_connection(server: "test_id_server_1", end_time: Time.now + 10.minutes) do
          test_unique_ids(10)
          assert_equal 1, GlobalUid::Base.connections.size
          assert_equal 'global_uid_test_id_server_2', GlobalUid::Base.connections[0].current_database

          after_timeout_end_time = Time.now + 11.minutes
          Time.stubs(:now).returns(after_timeout_end_time)

          test_unique_ids(10)
          assert_equal 2, GlobalUid::Base.connections.size
        end
      end
    end

    describe "With a server timing out on query" do
      before do
        GlobalUid::Base.connections.first.stubs(:insert).raises(GlobalUid::TimeoutException)
        # trigger the failure -- have to do it it a bunch of times, as one call might not hit the server
        # Even so there's a 1/(2^32) possibility of this test failing.
        32.times { WithGlobalUID.create! }
      end

      it "pull the server out of the pool" do
        assert_equal 1, GlobalUid::Base.connections.size
      end

      it "get ids from the remaining server" do
        test_unique_ids
      end

      it "eventually retry the connection" do
        assert_equal 1, GlobalUid::Base.connections.size

        awhile = Time.now + 10.minutes
        Time.stubs(:now).returns(awhile)

        test_unique_ids
        assert_equal 2, GlobalUid::Base.connections.size
      end
    end

    describe "With both servers throwing exceptions" do
      before do
        # would prefer to do the below, but need Mocha 0.9.10 to do so
        # ActiveRecord::ConnectionAdapters::MysqlAdapter.any_instance.stubs(:execute).raises(ActiveRecord::StatementInvalid)
        GlobalUid::Base.with_connections do |connection|
          connection.stubs(:insert).raises(ActiveRecord::StatementInvalid)
        end
      end

      it "raise a NoServersAvailableException" do
        assert_raises(GlobalUid::NoServersAvailableException) do
          WithGlobalUID.create!
        end
      end

      it "retry the servers immediately after failure" do
        assert_raises(GlobalUid::NoServersAvailableException) do
          WithGlobalUID.create!
        end

        assert WithGlobalUID.create!
      end
    end

    describe "with per-process_affinity" do
      before do
        GlobalUid::Base.global_uid_options[:per_process_affinity] = true
      end

      it "increment sequentially" do
        last_id = 0
        10.times do
          this_id = WithGlobalUID.create!.id
          assert_operator this_id, :>, last_id
        end
      end

      after do
        GlobalUid::Base.global_uid_options[:per_process_affinity] = false
      end
    end

    after do
      reset_connections!
      CreateWithNoParams.down
      CreateWithoutGlobalUIDs.down
    end
  end

  describe "with forking" do
    def parent_child_fork_values
      IO.pipe do |read_pipe, write_pipe|
        parent_value = yield.to_s
        pid = fork do
          write_pipe.write yield.to_s
        end
        Process.wait pid
        write_pipe.close
        child_value = read_pipe.read
        [parent_value, child_value]
      end
    end

    it "tests our helper method" do
      p, c = parent_child_fork_values { 1 }
      assert_equal c, p
      p, c = parent_child_fork_values { $$ }
      refute_equal c, p
    end

    it "creates new MySQL connections" do
      # Ensure the parent has a connection
      refute_empty GlobalUid::Base.setup_connections!
      parent_value, child_value = parent_child_fork_values { GlobalUid::Base.connections.map(&:object_id) }
      refute_equal child_value, parent_value
    end
  end

  describe "threads" do
    before do
      CreateWithNoParams.up
    end

    it "work" do
      reset_connections!
      2.times.map do
        Thread.new do
          100.times { WithGlobalUID.create! }
        end
      end.each(&:join)
    end

    after do
      CreateWithNoParams.down
    end
  end

  describe "generate_many_uids" do
    before do
      CreateWithNoParams.up
    end

    it "generates many unique ids" do
      uids = WithGlobalUID.generate_many_uids(100)
      assert_equal uids.sort, uids
      assert_equal uids.uniq, uids
    end

    after do
      CreateWithNoParams.down
    end
  end

  private

  def show_create_sql(klass, table)
    klass.connection.select_rows("show create table #{table}")[0][1]
  end

  def with_modified_connections(increment:, servers:)
    modified_connection = lambda do |config|
      ActiveRecord::Base.__minitest_stub__mysql2_connection(config).tap do |connection|
        if servers.any? { |name| config["database"].include?(name) }
          connection.execute("SET SESSION auto_increment_increment = #{increment}")
        end
      end
    end
    ActiveRecord::Base.stub :mysql2_connection, modified_connection do
      reset_connections!
      yield
    end
  end
end
