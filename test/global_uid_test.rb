require_relative 'test_helper'

class CreateWithNoParams < ActiveRecord::Migration
  group :change if self.respond_to?(:group)

  def self.up
    create_table :with_global_uids do |t|
      t.string  :description
    end
  end

  def self.down
    drop_table :with_global_uids
  end
end

class CreateWithExplicitUidTrue < ActiveRecord::Migration
  group :change if self.respond_to?(:group)

  def self.up
    create_table :with_global_uids, :use_global_uid => true do |t|
      t.string  :description
    end
  end

  def self.down
    drop_table :with_global_uids, :use_global_uid => true
  end
end

class CreateWithNamedID < ActiveRecord::Migration
  group :change if self.respond_to?(:group)

  def self.up
    create_table :with_global_uids, :id => 'hello' do |t|
      t.string  :description
    end
  end

  def self.down
    drop_table :with_global_uids
  end
end

class CreateWithoutGlobalUIDs < ActiveRecord::Migration
  group :change if self.respond_to?(:group)

  def self.up
    create_table :without_global_uids, :use_global_uid => false do |t|
      t.string  :description
    end
  end

  def self.down
    drop_table :without_global_uids, :use_global_uid => false
  end
end

class WithGlobalUID < ActiveRecord::Base
end

class WithoutGlobalUID < ActiveRecord::Base
end

class Parent < ActiveRecord::Base
  def self.reset
    @global_uid_disabled = nil
  end
end

class ParentSubclass < Parent
end

class ParentSubclassSubclass < ParentSubclass
end

class GlobalUIDTest < ActiveSupport::TestCase
  ActiveRecord::Migration.verbose = false

  context "#global_uid_disabled" do
    setup do
      [ Parent, ParentSubclass, ParentSubclassSubclass ].each { |k| k.reset }
    end

    should "default to the parent value or false" do
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

  context "migrations" do
    setup do
      restore_defaults!
      reset_connections!
      drop_old_test_tables!
    end

    context "without explicit parameters" do
      context "with global-uid enabled" do
        setup do
          GlobalUid::Base.global_uid_options[:disabled] = false
          GlobalUid::Base.global_uid_options[:storage_engine] = "InnoDB"
          CreateWithNoParams.up
          @create_table = show_create_sql(WithGlobalUID, "with_global_uids").split("\n")
        end

        should "create the global_uids table" do
          GlobalUid::Base.with_connections do |cx|
            assert cx.table_exists?('with_global_uids_ids')
          end
        end

        should "create global_uids tables with matching ids" do
          GlobalUid::Base.with_connections do |cx|
            foo = cx.select_all("select id from with_global_uids_ids")
            assert(foo.first['id'].to_i == 1)
          end
        end

        should "create tables with the given storage_engine" do
          GlobalUid::Base.with_connections do |cx|
            foo = cx.select_all("show create table with_global_uids_ids")
            assert_match /ENGINE=InnoDB/, foo.first.values.join
          end

        end

        should "tear off the auto_increment part of the primary key from the created table" do
          id_line = @create_table.grep(/\`id\` int/i).first
          assert_no_match /auto_increment/i, id_line
        end

        should "create a primary key on id" do
          assert @create_table.grep(/primary key/i).size > 0
        end

        teardown do
          CreateWithNoParams.down
        end
      end

      context "dropping a table" do
        should "not drop the global-uid tables" do
          CreateWithNoParams.up
          GlobalUid::Base.with_connections do |cx|
            assert cx.table_exists?('with_global_uids_ids')
          end

          CreateWithNoParams.down
          GlobalUid::Base.with_connections do |cx|
            assert cx.table_exists?('with_global_uids_ids')
          end
        end
      end

      context "with global-uid disabled, globally" do
        setup do
          GlobalUid::Base.global_uid_options[:disabled] = true
          CreateWithNoParams.up
        end

        should "not create the global_uids table" do
          GlobalUid::Base.with_connections do |cx|
            assert !cx.table_exists?('with_global_uids_ids')
          end
        end

        teardown do
          CreateWithNoParams.down
          GlobalUid::Base.global_uid_options[:disabled] = false
        end
      end

      context "with a named ID key" do
        setup do
          CreateWithNamedID.up
        end

        should "preserve the name of the ID key" do
          @create_table = show_create_sql(WithGlobalUID, "with_global_uids").split("\n")
          assert(@create_table.grep(/hello.*int/i))
          assert(@create_table.grep(/primary key.*hello/i))
        end

        teardown do
          CreateWithNamedID.down
        end
      end
    end

    context "with :use_global_uid => true" do
      context "dropping a table" do
        should "drop the global-uid tables" do
          CreateWithExplicitUidTrue.up
          GlobalUid::Base.with_connections do |cx|
            assert cx.table_exists?('with_global_uids_ids')
          end

          CreateWithExplicitUidTrue.down
          GlobalUid::Base.with_connections do |cx|
            assert !cx.table_exists?('with_global_uids_ids')
          end
        end
      end
    end

    context "with global-uid disabled in the migration" do
      setup do
        CreateWithoutGlobalUIDs.up
        @create_table = show_create_sql(WithoutGlobalUID, "without_global_uids").split("\n")
      end

      should "not create the global_uids table" do
        GlobalUid::Base.with_connections do |cx|
          assert !cx.table_exists?('without_global_uids_ids')
        end
      end

      should "create standard auto-increment tables" do
        id_line = @create_table.grep(/.id. int/i).first
        assert_match /auto_increment/i, id_line
      end

      teardown do
        CreateWithoutGlobalUIDs.down
      end
    end

    if ActiveRecord::VERSION::MAJOR == 4
      context "schema dumping" do
        setup do
          CreateWithoutGlobalUIDs.up
          CreateWithNoParams.up
        end

        should "set global_uid flags as appropriate" do
          stream = StringIO.new
          ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
          stream.rewind
          schema = stream.read

          with_line = schema.split("\n").grep(/with_global_uids/).first
          assert with_line =~ /use_global_uid: true/

          without_line = schema.split("\n").grep(/without_global_uids/).first
          assert without_line =~ /use_global_uid: false/
        end

        teardown do
          CreateWithoutGlobalUIDs.down
          CreateWithNoParams.down
        end
      end
    end
  end

  context "With InnoDB engine" do
    setup do
      reset_connections!
      drop_old_test_tables!
      restore_defaults!
      GlobalUid::Base.global_uid_options[:storage_engine] = "InnoDB"
      CreateWithNoParams.up
      CreateWithoutGlobalUIDs.up
    end

    should "interleave single and multiple uids" do
      test_interleave
    end

    teardown do
      GlobalUid::Base.global_uid_options[:storage_engine] = nil
      reset_connections!
      CreateWithNoParams.down
      CreateWithoutGlobalUIDs.down
    end
  end

  context "With GlobalUID" do
    setup do
      reset_connections!
      drop_old_test_tables!
      restore_defaults!
      CreateWithNoParams.up
      CreateWithoutGlobalUIDs.up
    end

    context "normally" do
      should "create tables with the default MyISAM storage engine" do
        GlobalUid::Base.with_connections do |cx|
          foo = cx.select_all("show create table with_global_uids_ids")
          assert_match /ENGINE=MyISAM/, foo.first.values.join
        end
      end

      should "get a unique id" do
        test_unique_ids
      end

      should "get bulk ids" do
        res = GlobalUid::Base.get_many_uids_for_class(WithGlobalUID, 10)
        assert res.size == 10
        res += GlobalUid::Base.get_many_uids_for_class(WithGlobalUID, 10)
        assert res.uniq.size == 20
        # starting value of 1 with a step of 5, so we should get 6,11,16...
        res.each_with_index do |val, i|
          assert_equal val, ((i + 1) * 5) + 1
        end
      end

      should "interleave single and multiple uids" do
        test_interleave
      end
    end

    context "reserving ids" do
      should "get 10 in bulk" do
        WithGlobalUID.with_reserved_global_uids(10) do
          WithGlobalUID.create!
          # now we should be able to run without ever touching the cx again
          GlobalUid::Base.get_connections.each.expects(:insert).never
          GlobalUid::Base.get_connections.each.expects(:select_value).never
          9.times { WithGlobalUID.create! }
        end

        GlobalUid::Base.get_connections.first.expects(:insert).once.returns(50)
        WithGlobalUID.create!
      end
    end

    context "With a timing out server" do
      setup do
        reset_connections!
        @a_decent_cx = GlobalUid::Base.new_connection(GlobalUid::Base.global_uid_servers.first, 50, 1, 5)
        ActiveRecord::Base.stubs(:mysql2_connection).raises(GlobalUid::ConnectionTimeoutException).then.returns(@a_decent_cx)
        @connections = GlobalUid::Base.get_connections
      end

      should "limp along with one functioning server" do
        assert @connections.include?(@a_decent_cx)
        assert_equal GlobalUid::Base.global_uid_servers.size - 1,  @connections.size, "get_connections size"
      end

      should "eventually retry the connection and get it back in place" do
        # clear the state machine expectation
        ActiveRecord::Base.mysql2_connection rescue nil
        ActiveRecord::Base.mysql2_connection rescue nil

        awhile = Time.now + 10.hours
        Time.stubs(:now).returns(awhile)

        assert GlobalUid::Base.get_connections.size == GlobalUid::Base.global_uid_servers.size

      end

      should "get some unique ids" do
        test_unique_ids
      end
    end

    context "With a server timing out on query" do
      setup do
        reset_connections!
        @old_size = GlobalUid::Base.get_connections.size # prime them
        GlobalUid::Base.get_connections.first.stubs(:insert).raises(GlobalUid::TimeoutException)
        # trigger the failure -- have to do it it a bunch of times, as one call might not hit the server
        # Even so there's a 1/(2^32) possibility of this test failing.
        32.times do WithGlobalUID.create! end
      end

      should "pull the server out of the pool" do
        assert GlobalUid::Base.get_connections.size == @old_size - 1
      end

      should "get ids from the remaining server" do
        test_unique_ids
      end

      should "eventually retry the connection" do
        awhile = Time.now + 10.hours
        Time.stubs(:now).returns(awhile)

        assert GlobalUid::Base.get_connections.size == GlobalUid::Base.global_uid_servers.size
      end
    end

    context "With both servers throwing exceptions" do
      setup do
        # would prefer to do the below, but need Mocha 0.9.10 to do so
        # ActiveRecord::ConnectionAdapters::MysqlAdapter.any_instance.stubs(:execute).raises(ActiveRecord::StatementInvalid)
        GlobalUid::Base.with_connections do |cx|
          cx.stubs(:insert).raises(ActiveRecord::StatementInvalid)
        end
      end

      should "raise a NoServersAvailableException" do
        assert_raises(GlobalUid::NoServersAvailableException) do
          WithGlobalUID.create!
        end
      end

      should "retry the servers immediately after failure" do
        assert_raises(GlobalUid::NoServersAvailableException) do
          WithGlobalUID.create!
        end

        assert WithGlobalUID.create!
      end
    end

    context "with per-process_affinity" do
      setup do
        GlobalUid::Base.global_uid_options[:per_process_affinity] = true
      end

      should "increment sequentially" do
        last_id = 0
        10.times do
          this_id = WithGlobalUID.create!.id
          assert this_id > last_id
        end
      end

      teardown do
        GlobalUid::Base.global_uid_options[:per_process_affinity] = false
      end
    end

    teardown do
      mocha_teardown # tear down mocha early to prevent some of this being tied to mocha expectations
      reset_connections!
      CreateWithNoParams.down
      CreateWithoutGlobalUIDs.down
    end
  end

  context "In dry-run mode" do
    setup do
      reset_connections!
      drop_old_test_tables!
      GlobalUid::Base.global_uid_options[:dry_run] = true
      CreateWithNoParams.up
    end

    should "increment normally1" do
      (1..10).each do |i|
        assert_equal i, WithGlobalUID.create!.id
      end
    end

    should "insert into the UID servers nonetheless" do
      GlobalUid::Base.expects(:get_uid_for_class).at_least(10)
      10.times { WithGlobalUID.create! }
    end

    should "log the results" do
      ActiveRecord::Base.logger.expects(:info).at_least(10)
      10.times { WithGlobalUID.create! }
    end

    teardown do
      reset_connections!
      CreateWithNoParams.down
      GlobalUid::Base.global_uid_options[:dry_run] = false
    end
  end

  context "threads" do
    setup do
      reset_connections!
      drop_old_test_tables!
      restore_defaults!
      CreateWithNoParams.up
    end

    should "work" do
      reset_connections!
      2.times.map do
        Thread.new do
          100.times { WithGlobalUID.create! }
        end
      end.each(&:join)
    end

    teardown do
      CreateWithNoParams.down
    end
  end

  private
  def test_unique_ids
    seen = {}
    (0..10).each do
      foo = WithGlobalUID.new
      foo.save
      assert !foo.id.nil?
      assert foo.description.nil?
      assert !seen.has_key?(foo.id)
      seen[foo.id] = 1
    end
  end

  def test_interleave
    old_per_process_affinity = GlobalUid::Base.global_uid_options[:per_process_affinity]
    begin
      # Set per process affinity to get deterministic results
      GlobalUid::Base.global_uid_options[:per_process_affinity] = true
      first_id = GlobalUid::Base.get_uid_for_class(WithGlobalUID)
      res = [first_id]
      res += GlobalUid::Base.get_many_uids_for_class(WithGlobalUID, 10)
      assert_equal 11, res.uniq.size
      res += [GlobalUid::Base.get_uid_for_class(WithGlobalUID)]
      res += GlobalUid::Base.get_many_uids_for_class(WithGlobalUID, 10)
      assert_equal 22, res.uniq.size
      # starting value of first_id with a step of 5
      res.each_with_index do |val, i|
        assert_equal val, i * 5 + first_id
      end
    ensure
      GlobalUid::Base.global_uid_options[:per_process_affinity] = old_per_process_affinity
    end
  end

  def drop_old_test_tables!
    GlobalUid::Base.with_connections do |cx|
      cx.execute("DROP TABLE IF exists with_global_uids_ids")
    end
  end

  def reset_connections!
    GlobalUid::Base.servers = nil
  end

  def restore_defaults!
    GlobalUid::Base.global_uid_options[:disabled] = false
    GlobalUid::Base.global_uid_options[:dry_run] = false
  end

  def show_create_sql(klass, table)
    klass.connection.select_rows("show create table #{table}")[0][1]
  end
end


