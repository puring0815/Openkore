package TaskWithSubtaskTest;

use Test::More;
use Task::WithSubtask;

sub start {
	print "### Starting TaskWithSubtaskTest\n";
	testBasicUsage();
	testStop();
	testSubtaskFailure();
}

sub testBasicUsage {
	print "Testing basic usage...\n";
	my $task = new TaskWithSubtaskTest::TestTask();
	$task->activate();

	$task->iterate();
	is($task->getStatus(), Task::RUNNING);
	ok(defined $task->getSubtask());

	$task->iterate();
	is($task->getStatus(), Task::RUNNING);
	ok(!defined $task->getSubtask());

	$task->iterate();
	is($task->getStatus(), Task::DONE);
}

sub testStop {
	print "Testing stop()...\n";
	my $task = new TaskWithSubtaskTest::TestTask();
	$task->activate();
	$task->iterate();
	$task->stop();
	is($task->getStatus(), Task::STOPPED);

	$task = new TaskWithSubtaskTest::TestTask(autostop => 0);
	$task->activate();
	$task->iterate();
	$task->stop();
	is($task->getStatus(), Task::RUNNING);
	$task->iterate();
	is($task->getStatus(), Task::DONE);
}

sub testSubtaskFailure {
	print "Testing subtask failure...\n";
	my $task = new TaskWithSubtaskTest::TestTask(autofail => 0);
	$task->activate();
	$task->iterate();
	$task->getSubtask()->markFailed();
	$task->iterate();
	is($task->getStatus(), Task::RUNNING);
	$task->iterate();
	is($task->getStatus(), Task::DONE);
	ok(!defined $task->getError());

	my $task = new TaskWithSubtaskTest::TestTask();
	$task->activate();
	$task->iterate();
	$task->getSubtask()->markFailed();
	$task->iterate();
	is($task->getStatus(), Task::DONE);
	ok(defined $task->getError());
}


package TaskWithSubtaskTest::TestTask;
# A test task which has exactly one subtask. It works as follows:
# - The first iteration will switch context to the subtask.
# - The second iteration will run the subtask, which in turn only
#   runs one iteration before it's done.
# - After the third iteration, the task will complete.

use base qw(Task::WithSubtask);

sub activate {
	my ($self) = @_;
	$self->SUPER::activate();
	$self->{state} = 'Normal';
}

sub iterate {
	my ($self) = @_;
	return if (!$self->SUPER::iterate());

	if ($self->{state} eq 'Normal') {
		$self->setSubtask(new TaskWithSubtaskTest::TestSubtask);
		$self->{state} = 'Subtask Done';
	} else {
		$self->setDone();
	}
}


package TaskWithSubtaskTest::TestSubtask;

use base qw(Task);

sub iterate {
	my ($self) = @_;
	$self->SUPER::iterate();
	if ($self->{failed}) {
		$self->setError(0, "foo");
	} else {
		$self->setDone();
	}
}

sub markFailed {
	my ($self) = @_;
	$self->{failed} = 1;
}

1;