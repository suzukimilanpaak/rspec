require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module DSL
    describe Example, " instance" do
      setup do
        @reporter = mock("reporter")
        Example.send(:current=, nil)
      end

      specify "should add itself to reporter when calling run dry" do
        spec=Example.new("spec") {}
        @reporter.should_receive(:spec_started).with("spec")
        @reporter.should_receive(:spec_finished).with("spec")
        spec.run(@reporter, nil, nil, true, nil)
      end

      specify "should add itself to reporter when fails" do
        error=RuntimeError.new
        spec=Example.new("spec") do
          raise(error)
        end
        @reporter.should_receive(:spec_started).with("spec")
        @reporter.should_receive(:spec_finished).with("spec", error, "spec")
        spec.run(@reporter, nil, nil, nil, nil)
      end

      specify "should add itself to reporter when passes" do
        spec=Example.new("spec") {}
        @reporter.should_receive(:spec_started).with("spec")
        @reporter.should_receive(:spec_finished).with("spec", nil, nil)
        spec.run(@reporter, nil, nil, nil, nil)
      end

      specify "should not run spec if setup fails" do
        spec_ran = false
        spec=Example.new("should pass") do
          spec_ran = true
        end
        @reporter.stub!(:spec_started)
        @reporter.stub!(:spec_finished)
        setup = proc {raise "Setup error"}
        spec.run(@reporter, setup, nil, nil, Object.new)
        spec_ran.should == false
        @reporter.__verify
      end

      specify "should run spec in scope of execution context" do
        exec_context_class = Class.new
        spec=Example.new("should pass") do
          self.instance_of?(Example).should == false
          self.instance_of?(exec_context_class).should == true
        end
        @reporter.should_receive(:spec_started).with("should pass")
        @reporter.should_receive(:spec_finished).with("should pass", nil, nil)
        spec.run(@reporter, nil, nil, nil, exec_context_class.new)
        @reporter.__verify
      end

      specify "should run teardown even when main block fails" do
        spec=Example.new("spec") do
          raise("in body")
        end
        teardown=lambda do
          raise("in teardown")
        end
        @reporter.should_receive(:spec_started).with("spec")
        @reporter.should_receive(:spec_finished) do |spec, error, location|
          spec.should_eql("spec")
          location.should_eql("spec")
          error.message.should_eql("in body")
        end
        spec.run(@reporter, nil, teardown, nil, nil)
      end

      specify "should supply setup as spec name if failure in setup" do
        spec=Example.new("spec") {}
        setup=lambda { raise("in setup") }
        @reporter.should_receive(:spec_started).with("spec")
        @reporter.should_receive(:spec_finished) do |name, error, location|
          name.should_eql("spec")
          error.message.should_eql("in setup")
          location.should_eql("setup")
        end
        spec.run(@reporter, setup, nil, nil, nil)
      end

      specify "should supply teardown as failure location if failure in teardown" do
        spec = Example.new("spec") {}
        teardown = lambda { raise("in teardown") }
        @reporter.should_receive(:spec_started).with("spec")
        @reporter.should_receive(:spec_finished) do |name, error, location|
          name.should_eql("spec")
          error.message.should_eql("in teardown")
          location.should_eql("teardown")
        end
        spec.run(@reporter, nil, teardown, nil, nil)
      end

      specify "should verify mocks after teardown" do
        spec=Example.new("spec") do
          mock=Spec::Mocks::Mock.new("a mock")
          mock.should_receive(:poke)
        end
        @reporter.should_receive(:spec_started).with("spec")
        @reporter.should_receive(:spec_finished) do |spec_name, error|
          spec_name.should_eql("spec")
          error.message.should_match(/expected :poke with \(any args\) once, but received it 0 times/)
        end
        spec.run(@reporter, nil, nil, nil, Object.new)
      end
      
      specify "should accept an options hash following the spec name" do
        spec = Example.new("name", :key => 'value')
      end

      specify "should update the current spec only when running the spec" do
        @reporter.stub!(:spec_started)
        @reporter.stub!(:spec_finished)

        spec = Example.new("spec") do
          Example.current.should == spec
        end

        Example.current.should_be_nil
        setup = proc {Example.current.should == spec}
        teardown = proc {Example.current.should == spec}
        spec.run(@reporter, setup, teardown, nil, Object.new)
        Example.current.should_be_nil
      end

      specify "should notify before_setup callbacks before setup" do
        spec = Example.new("spec")
        @reporter.stub!(:spec_started)
        @reporter.stub!(:spec_finished)

        mock = mock("setup mock")
        mock.should_receive(:before_setup).ordered
        mock.should_receive(:setup).ordered

        spec.before_setup {mock.before_setup}
        setup = proc {mock.setup}
        spec.run(@reporter, setup, nil, nil, Object.new)
      end

      specify "should notify after_teardown callbacks after teardown" do
        spec = Example.new("spec")
        @reporter.stub!(:spec_started)
        @reporter.stub!(:spec_finished)

        mock = mock("teardown mock")
        mock.should_receive(:teardown).ordered
        mock.should_receive(:after_teardown).ordered

        spec.after_teardown {mock.after_teardown}
        teardown = proc {mock.teardown}
        spec.run(@reporter, nil, teardown, nil, Object.new)
      end
      
      specify "should report NAME NOT GENERATED when told to use generated description but none is generated" do
        spec = Example.new(:__generate_description)
        @reporter.stub!(:spec_started)
        @reporter.should_receive(:spec_finished).with("NAME NOT GENERATED", :anything, :anything)
        spec.run(@reporter, nil, nil, nil, Object.new)
      end
      
      specify "should use generated description when told to and it is available" do
        spec = Example.new(:__generate_description) {
          5.should == 5
        }
        @reporter.stub!(:spec_started)
        @reporter.should_receive(:spec_finished).with("should == 5", :anything, :anything)
        spec.run(@reporter, nil, nil, nil, Object.new)
      end
      
      specify "should unregister description_generated callback (lest a memory leak should build up)" do
        spec = Example.new("something")
        @reporter.stub!(:spec_started)
        @reporter.stub!(:spec_finished)
        Spec::Matchers.should_receive(:unregister_callback)
        spec.run(@reporter, nil, nil, nil, Object.new)
      end
    end
  end
end
