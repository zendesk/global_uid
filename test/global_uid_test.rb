# frozen_string_literal: true
require_relative 'test_helper'
require_relative 'migrations'
require_relative 'models'

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
          GlobalUid::Base.with_connections do |cx|
            assert table_exists?(cx, 'with_global_uids_ids'), 'Table should exist'
          end
        end

        it "create global_uids tables with matching ids" do
          GlobalUid::Base.with_connections do |cx|
            foo = cx.select_all("select id from with_global_uids_ids")
            assert_equal(foo.first['id'].to_i, 1)
          end
        end

        it "create tables with the given storage_engine" do
          GlobalUid::Base.with_connections do |cx|
            foo = cx.select_all("show create table with_global_uids_ids")
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
          GlobalUid::Base.with_connections do |cx|
            assert table_exists?(cx, 'with_global_uids_ids'), 'Table should exist'
          end

          CreateWithNoParams.down
          GlobalUid::Base.with_connections do |cx|
            assert table_exists?(cx, 'with_global_uids_ids'), 'Table should be dropped'
          end
        end
      end

      describe "with global-uid disabled, globally" do
        before do
          GlobalUid::Base.global_uid_options[:disabled] = true
          CreateWithNoParams.up
        end

        it "not create the global_uids table" do
          GlobalUid::Base.with_connections do |cx|
            assert !table_exists?(cx, 'with_global_uids_ids'), 'Table should not have been created'
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
          GlobalUid::Base.with_connections do |cx|
            assert table_exists?(cx, 'with_global_uids_ids'), 'Table should exist'
          end

          CreateWithExplicitUidTrue.down
          GlobalUid::Base.with_connections do |cx|
            assert !table_exists?(cx, 'with_global_uids_ids'), 'Table should be dropped'
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
        GlobalUid::Base.with_connections do |cx|
          assert !table_exists?(cx, 'without_global_uids_ids'), 'Table should not not have been created'
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

  describe "With GlobalUID" do
    before do
      CreateWithNoParams.up
      CreateWithoutGlobalUIDs.up
    end

    describe "normally" do
      it "create tables with the default MyISAM storage engine" do
        GlobalUid::Base.with_connections do |cx|
          foo = cx.select_all("show create table with_global_uids_ids")
          assert_match(/ENGINE=MyISAM/, foo.first.values.join)
        end
      end

      it "get a unique id" do
        test_unique_ids
      end
    end

    describe "With a timing out server" do
      before do
        reset_connections!
        @a_decent_cx = GlobalUid::Base.new_connection(GlobalUid::Base.global_uid_servers.first, 50, 1, 5)
        ActiveRecord::Base.stubs(:mysql2_connection).raises(GlobalUid::ConnectionTimeoutException).then.returns(@a_decent_cx)
        @connections = GlobalUid::Base.get_connections
      end

      it "limp along with one functioning server" do
        assert_includes @connections, @a_decent_cx
        assert_equal GlobalUid::Base.global_uid_servers.size - 1,  @connections.size, "get_connections size"
      end

      it "eventually retry the connection and get it back in place" do
        # clear the state machine expectation
        ActiveRecord::Base.mysql2_connection rescue nil
        ActiveRecord::Base.mysql2_connection rescue nil

        awhile = Time.now + 10.hours
        Time.stubs(:now).returns(awhile)

        assert_equal GlobalUid::Base.get_connections.size, GlobalUid::Base.global_uid_servers.size
      end

      it "get some unique ids" do
        test_unique_ids
      end
    end

    describe "With a server timing out on query" do
      before do
        reset_connections!
        @old_size = GlobalUid::Base.get_connections.size # prime them
        GlobalUid::Base.get_connections.first.stubs(:insert).raises(GlobalUid::TimeoutException)
        # trigger the failure -- have to do it it a bunch of times, as one call might not hit the server
        # Even so there's a 1/(2^32) possibility of this test failing.
        32.times do WithGlobalUID.create! end
      end

      it "pull the server out of the pool" do
        assert_equal GlobalUid::Base.get_connections.size, @old_size - 1
      end

      it "get ids from the remaining server" do
        test_unique_ids
      end

      it "eventually retry the connection" do
        awhile = Time.now + 10.hours
        Time.stubs(:now).returns(awhile)

        assert_equal GlobalUid::Base.get_connections.size, GlobalUid::Base.global_uid_servers.size
      end
    end

    describe "With both servers throwing exceptions" do
      before do
        # would prefer to do the below, but need Mocha 0.9.10 to do so
        # ActiveRecord::ConnectionAdapters::MysqlAdapter.any_instance.stubs(:execute).raises(ActiveRecord::StatementInvalid)
        GlobalUid::Base.with_connections do |cx|
          cx.stubs(:insert).raises(ActiveRecord::StatementInvalid)
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

  describe "In dry-run mode" do
    before do
      GlobalUid::Base.global_uid_options[:dry_run] = true
      CreateWithNoParams.up
    end

    it "increment normally1" do
      (1..10).each do |i|
        assert_equal i, WithGlobalUID.create!.id
      end
    end

    it "insert into the UID servers nonetheless" do
      GlobalUid::Base.expects(:get_uid_for_class).at_least(10)
      10.times { WithGlobalUID.create! }
    end

    it "log the results" do
      ActiveRecord::Base.logger.expects(:info).at_least(10)
      10.times { WithGlobalUID.create! }
    end

    after do
      reset_connections!
      CreateWithNoParams.down
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
      refute_empty GlobalUid::Base.get_connections
      parent_value, child_value = parent_child_fork_values { GlobalUid::Base.get_connections.map(&:object_id) }
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

  def test_unique_ids
    seen = {}
    (0..10).each do
      foo = WithGlobalUID.new
      foo.save
      refute_nil foo.id
      assert_nil foo.description
      refute seen.has_key?(foo.id)
      seen[foo.id] = 1
    end
  end

  def reset_connections!
    GlobalUid::Base.servers = nil
  end

  def restore_defaults!
    GlobalUid::Base.global_uid_options[:storage_engine] = nil
    GlobalUid::Base.global_uid_options[:disabled] = false
    GlobalUid::Base.global_uid_options[:dry_run] = false
  end

  def show_create_sql(klass, table)
    klass.connection.select_rows("show create table #{table}")[0][1]
  end
end
