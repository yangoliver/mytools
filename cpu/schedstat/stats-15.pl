#!/usr/bin/perl

use Getopt::Std;

$curr_version = 12;

$YLD_BOTH_EMPTY		= 1;
$YLD_ACT_EMPTY		= 2;
$YLD_EXP_EMPTY		= 3;
$YLD_CNT		= 4;
$SCHED_NOSWITCH		= 5;
$SCHED_CNT		= 6;
$SCHED_GOIDLE		= 7;
$TTWU_CNT		= 8;
$TTWU_LOCAL		= 9;
$CPU_CPUTIME		= 10;
$CPU_RUNDELAY		= 11;
$CPU_TRIPCNT		= 12;

#
# per-domain stats
#
$LB_CNT_IDLE		= 2;
$LB_NOT_NEEDED_IDLE	= 3;
$LB_FAILED_IDLE		= 4;
$LB_IMBALANCE_IDLE	= 5;
$PT_CNT_IDLE		= 6;
$PT_HOT_IDLE		= 7;
$LB_NOBUSYQ_IDLE	= 8;
$LB_NOBUSYG_IDLE	= 9;

$LB_CNT_NOIDLE		= 10;
$LB_NOT_NEEDED_NOIDLE	= 11;
$LB_FAILED_NOIDLE	= 12;
$LB_IMBALANCE_NOIDLE	= 13;
$PT_CNT_NOIDLE		= 14;
$PT_HOT_NOIDLE		= 15;
$LB_NOBUSYQ_NOIDLE	= 16;
$LB_NOBUSYG_NOIDLE	= 17;

$LB_CNT_NEWIDLE		= 18;
$LB_NOT_NEEDED_NEWIDLE	= 19;
$LB_FAILED_NEWIDLE	= 20;
$LB_IMBALANCE_NEWIDLE	= 11;
$PT_CNT_NEWIDLE		= 22;
$PT_HOT_NEWIDLE		= 23;
$LB_NOBUSYQ_NEWIDLE	= 24;
$LB_NOBUSYG_NEWIDLE	= 25;

$ALB_CNT		= 26;
$ALB_FAILED		= 27;
$ALB_PUSHED		= 28;

$TTWU_WAKE_REMOTE	= 35;
$TTWU_MOVE_AFFINE	= 36;
$TTWU_MOVE_BALANCE	= 37;

die "Usage: $0 [-t] [file]\n" unless &getopts("tcd");

#
# @domain_diff_all is an array, for each field of domain data, of the sum
#	of that field across all cpus and all domains.
#
# @domain_diff_bycpu is an array of references to arrays. For each cpu, it
#	contains a reference to an array which sums each field in all its
#	domain stats.
#
# @diff is the array of runqueue data.
#
# @per_cpu_curr and @per_cpu_prev are arrays of runqueue data on a per cpu
#	basis for the current stats (just read) and previous stats.  These
#	are referenced to calculate @diff, above.  Fields beyond
#	$PT_LOST_IDLE are references to arrays of per-domain information
#	for this cpu; as many references are there are unique domains.
#
sub summarize_data {
    my $i;
    my $cpu, $domain;
    my @arr_curr, @arr_prev, @arr_diff;

    #
    # first we must sum up the diffs for the individual cpus
    #
    @diff = ();

    @domain_diff_all = ();
    foreach $cpu (0 .. $max_cpu) {
	@arr_curr = @{$per_cpu_curr[$cpu]};
	@arr_prev = @{$per_cpu_prev[$cpu]};
	foreach $i (1 .. 12) {
	    $arr_diff[$i] = $arr_curr[$i] - $arr_prev[$i];
	    $diff[$i] += $arr_diff[$i];
	}
	$per_cpu_diff[$cpu] = [ @arr_diff ];

	#
	# now stats from domains
	#
	@domain_diff_bycpu[$cpu] = [ ];
	foreach $domain (0..$max_domain) {
	    @arr_curr = @{@{$per_cpu_curr[$cpu]}[$domain+13]};
	    @arr_prev = @{@{$per_cpu_prev[$cpu]}[$domain+13]};
	    foreach $i (2..37) {
		#print "domain$domain: arr_curr[$i] ($arr_curr[$i]) -" .
		#    " arr_prev[$i] ($arr_prev[$i])\n";
		$arr_diff[$i] = $arr_curr[$i] - $arr_prev[$i];
		$diff[$domain+13][$i] += $arr_diff[$i];
		$domain_diff_bycpu[$cpu]->[i] += $arr_diff[$i];
		$domain_diff_all[$i] += $arr_diff[$i];
	    }
	    push @{$per_cpu_diff[$cpu]} , [ @arr_diff ];
	}
    }
}
    
$first = 2;
while (<>) {

    next if (/^$/);

    @curr = split;
    if ($curr[0] =~ /cpu(\d+)/) {
	$curr_cpu = $1;
	$per_cpu_curr[$curr_cpu] = [ @curr ];
	$max_cpu = $curr_cpu if ($curr_cpu > $max_cpu);
	next;
    }
    if ($curr[0] =~ /domain(\d+)/) {
	$arr = $per_cpu_curr[$curr_cpu];
	push @{$arr}, [ @curr ];
	#print "@{$arr}\n";
	#print "($curr_cpu,$1)$arr->[0],$arr->[$#{@{$arr}}]->[0]\n";
	#print "$#{@{$arr}}\n";
	$max_domain = $1 if ($1 > $max_domain);
	next;
    }
    if ($curr[0] eq "version") {
	if ($curr[1] != $curr_version) {
	    die "$0: Version mismatch: input is version $curr[1] but this" .
		" tool\nis for version $curr_version.\n";
	}
	if (!$first) {


	    #
	    # display diffs
	    #
	    if (!$opt_t) {
		summarize_data();
		$diff[0] = "diff";
		print "\n";
		print_diffs();
		@per_cpu_prev = @per_cpu_curr;
	    } else {
		@per_cpu_prev = @per_cpu_curr if (!defined(@per_cpu_prev));
	    }
	} else {
	    @per_cpu_prev = @per_cpu_curr if (!--$first && !defined(@per_cpu_prev));
	}
	next;
    }
    if ($curr[0] eq "timestamp") {
	if ($curr[1] > $otimestamp) {
	    $delta = $curr[1] - $otimestamp;
	} else {
	    # timestamp rolled over
	    $delta = $curr[1] + (~0 - $otimestamp);
	    print "ROLLOVER! (delta=$delta)\n";
	}
	$otimestamp = $curr[1];
	$timestart = $delta if (!$timestart);
	$timestamp += $delta;
	next;
    }

    #
    # format of line in /proc/schedstat
    #
    # cpuN 1 2 3 4 5 6 7 8 9 10 11 12
    # domainN xxxxxxxx 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37
    #
    # version == 12
    #
    # These are the fields from the cpuN field, and deal with the runqueue
    # that cpu is in.  [The fields listed in the comments below are currently
    # incorrect, and will be updated within a few days.  The program, however,
    # uses the fields correctly.  -- Rick 11/11/05]
    #
    # NOTE: the active queue is considered empty if it has only one process
    #	in it, since obviously the process calling sched_yield is that process.
    #
    # First four are sched_yield statistics:
    #     1) # of times both the active and the expired queue were empty
    #     2) # of times just the active queue was empty
    #     3) # of times just the expired queue was empty
    #     4) # of times sched_yield() was called
    #
    # Next three are schedule() statistics:
    #     5) # of times the active queue had at least one other process on it.
    #     6) # of times we switched to the expired queue and reused it
    #     7) # of times schedule() was called
    #
    # Next two are statistics dealing with try_to_wake_up():
    #     8) # of times try_to_wake_up() was called
    #     9) # of times try_to_wake_up() was called for a task that last
    #        ran on this same cpu
    #
    # Next three are statistics dealing with scheduling latency:
    #	 10) sum of all time spent running by tasks on this processor (in ms)
    #	 11) sum of all time spent waiting to run by tasks on this processor
    #	     (in ms)
    #	 12) # of tasks (not necessarily unique) given to the processor
    #
    # These are the fields from the domainN field, and deal with each of the
    # domains the previously mentioned cpu is in. The first field is a bit
    # mask which indicates the span of the domain being described.
    #
    # Next twenty-four fields are statistics dealing with load_balance() and
    # pull_task():
    #   2) # of times in this domain load_balance() was called when the
    #      cpu was idle
    #   3) # of times in this domain load_balance() checked but found
    #      the load did not require balancing when the cpu was idle
    #   4) # of times in this domain load_balance() tried to move one or
    #      more tasks and failed, when the cpu was idle
    #   5) sum of imbalances discovered (if any) with each call to
    #      load_balance() in this domain when the cpu was idle
    #   6) # of times in this domain pull_task() was called when the cpu
    #      was idle
    #   7) # of times in this domain pull_task() was called even though
    #      the target task was cache-hot when idle
    #   8) # of times in this domain load_balance() was called but did
    #      not find a busier queue while the cpu was idle
    #   9) # of times in this domain a busier queue was found while the
    #      cpu was idle but no busier group was found
    #
    #  10) # of times in this domain load_balance() was called when the
    #      cpu was busy
    #  11) # of times in this domain load_balance() checked but found the
    #      load did not require balancing when busy
    #  12) # of times in this domain load_balance() tried to move one or
    #      more tasks and failed, when the cpu was busy
    #  13) sum of imbalances discovered (if any) with each call to
    #      load_balance() in this domain when the cpu was busy
    #  14) # of times in this domain pull_task() was called when busy
    #  15) # of times in this domain pull_task() was called even though the
    #      target task was cache-hot when busy
    #  16) # of times in this domain load_balance() was called but did not
    #      find a busier queue while the cpu was busy
    #  17) # of times in this domain a busier queue was found while the cpu
    #      was busy but no busier group was found
    #
    #  18) # of times in this domain load_balance() was called when the
    #      cpu was just becoming idle
    #  19) # of times in this domain load_balance() checked but found the
    #      load did not require balancing when the cpu was just becoming idle
    #  20) # of times in this domain load_balance() tried to move one or more
    #      tasks and failed, when the cpu was just becoming idle
    #  21) sum of imbalances discovered (if any) with each call to
    #      load_balance() in this domain when the cpu was just becoming idle
    #  22) # of times in this domain pull_task() was called when newly idle
    #  23) # of times in this domain pull_task() was called even though the
    #      target task was cache-hot when just becoming idle
    #  24) # of times in this domain load_balance() was called but did not
    #      find a busier queue while the cpu was just becoming idle
    #  25) # of times in this domain a busier queue was found while the cpu
    #      was just becoming idle but no busier group was found
    #
    # Next three are active_load_balance() statistics:
    #  26) # of times active_load_balance() was called
    #  27) # of times active_load_balance() tried to move a task and failed
    #  28) # of times active_load_balance() successfully moved a task 
    #
    # Next two are sched_balance_exec() statistics:
    #  29) # of times in this domain sched_balance_exec() successfully
    #      pushed a task to a new cpu
    #  30) # of times in this domain sched_balance_exec() tried but failed
    #      to push a task to a new cpu 
    #
    # Next three are try_to_wake_up() statistics:
    #  31) # of times in this domain try_to_wake_up() awoke a task that
    #      last ran on a different cpu in this domain
    #  32) # of times in this domain try_to_wake_up() moved a task to the
    #      waking cpu because it was cache-cold on its own cpu anyway
    #  33) # of times in this domain try_to_wake_up() moved a task to the
    #

}

summarize_data();
print_diffs() if ($opt_t);

sub print_diffs {
    my $t;

    if ($timestamp > $timestart) {
	$t = $timestamp-$timestart;
    } else {
	$t = $timestamp + (~0 - $timestart);
    }

    printf "%02d:%02d:%02d--------------------------------------------------------------\n",
	$t/3600000, ($t/60000)%60, ($t/1000)%60;

    #print "@domain_diff_all\n";
    #
    # sched_yield() stats
    #
    printf "    %7d          sys_sched_yield()\n", $diff[$YLD_CNT];
    printf "    %7d(%6.2f%%) found (only) active queue empty on current cpu\n",
	$diff[$YLD_ACT_EMPTY]-$diff[$YLD_BOTH_EMPTY],
	$diff[$YLD_CNT] ?
	    (100*($diff[$YLD_ACT_EMPTY]-$diff[$YLD_BOTH_EMPTY])/
		$diff[$YLD_CNT]) : 0
	if ($diff[$YLD_ACT_EMPTY]-$diff[$YLD_BOTH_EMPTY]);
    printf "    %7d(%6.2f%%) found (only) expired queue empty on current cpu\n",
	$diff[$YLD_EXP_EMPTY],
	$diff[$YLD_CNT] ? (100*$diff[$YLD_EXP_EMPTY]/$diff[$YLD_CNT]) : 0
	if ($diff[$YLD_EXP_EMPTY]);
    printf "    %7d(%6.2f%%) found both queues empty on current cpu\n",
	$diff[$YLD_BOTH_EMPTY],
	$diff[$YLD_CNT] ? (100*$diff[$YLD_BOTH_EMPTY]/$diff[$YLD_CNT]) : 0
	if ($diff[$YLD_BOTH_EMPTY]);
    printf "    %7d(%6.2f%%) found neither queue empty on current cpu\n\n",
	$diff[$YLD_CNT]-($diff[$YLD_EXP_EMPTY]+$diff[$YLD_ACT_EMPTY]),
	$diff[$YLD_CNT] ?
	    100*($diff[$YLD_CNT]-($diff[$YLD_EXP_EMPTY]+$diff[$YLD_ACT_EMPTY]))/
		$diff[$YLD_CNT] : 0
	if ($diff[$YLD_CNT]-($diff[$YLD_EXP_EMPTY]+$diff[$YLD_ACT_EMPTY]));

    #
    # schedule() stats
    #
    print "\n";
    printf "    %7d          schedule()\n", $diff[$SCHED_CNT];
    printf "    %7d(%6.2f%%) switched active and expired queues\n",
	$diff[$SCHED_CNT] - $diff[$SCHED_NOSWITCH], 
	(100*($diff[$SCHED_CNT] - $diff[$SCHED_NOSWITCH])/$diff[$SCHED_CNT])
	if ($diff[$SCHED_CNT]);
    printf "    %7d(%6.2f%%) used existing active queue\n",
	100*$diff[$SCHED_NOSWITCH]/$diff[$SCHED_CNT]
	if ($diff[$SCHED_NOSWITCH]);
    printf "    %7d(%6.2f%%) scheduled no process (left cpu idle)\n",
	$diff[$SCHED_GOIDLE], 100*$diff[$SCHED_GOIDLE]/$diff[$SCHED_CNT]
	if ($diff[$SCHED_CNT]);

    #
    # try_to_wake_up() stats
    #
    print "\n\n";
    printf "    %7d          try_to_wake_up()\n", $diff[$TTWU_CNT];
    printf "    %7d(%6.2f%%) task being awakened was last on same cpu as waker\n",
	$diff[$TTWU_LOCAL], 100*$diff[$TTWU_LOCAL]/$diff[$TTWU_CNT]
	if ($diff[$TTWU_CNT] && $diff[$TTWU_LOCAL]);
    printf "    %7d(%6.2f%%) task being awakened was last on different cpu than waker\n",
	$diff[$TTWU_CNT] - $diff[$TTWU_LOCAL], 
	100*($diff[$TTWU_CNT] - $diff[$TTWU_LOCAL])/$diff[$TTWU_CNT]
	if ($diff[$TTWU_CNT] && $diff[$TTWU_CNT] != $diff[$TTWU_LOCAL]);
    if (!$opt_d) {
	#
	# try_to_wake_up() stats
	#
	printf "                %7d(%6.2f%%) moved that task to the waking cpu because it was cache-cold\n",
	    $domain_diff_all[$TTWU_MOVE_AFFINE],
	    100*$domain_diff_all[$TTWU_MOVE_AFFINE]/$domain_diff_all[$TTWU_WAKE_REMOTE]
	    if ($domain_diff_all[$TTWU_MOVE_AFFINE]);
	printf "                %7d(%6.2f%%) moved that task to the waking cpu because the cpu's queue was unbalanced\n",
	    $domain_diff_all[$TTWU_MOVE_BALANCE],
	    100*$domain_diff_all[$TTWU_MOVE_BALANCE]/$domain_diff_all[$TTWU_WAKE_REMOTE]
	    if ($domain_diff_all[$TTWU_MOVE_BALANCE]);
	printf "                %7d(%6.2f%%) didn't move that task\n",
	    $domain_diff_all[$TTWU_WAKE_REMOTE] -
		$domain_diff_all[$TTWU_MOVE_AFFINE] - $domain_diff_all[$TTWU_MOVE_BALANCE],
	    100*($domain_diff_all[$TTWU_WAKE_REMOTE] -
		$domain_diff_all[$TTWU_MOVE_AFFINE] - $domain_diff_all[$TTWU_MOVE_BALANCE])
		/ $domain_diff_all[$TTWU_WAKE_REMOTE]
	    if ($domain_diff_all[$TTWU_WAKE_REMOTE] -
		$domain_diff_all[$TTWU_MOVE_AFFINE] -
		$domain_diff_all[$TTWU_MOVE_BALANCE]);
    }

    print "\n" if ($diff[TTWU_CNT]);

    #
    # latency stats
    #
    $totalcpu = $totaltripcnt = $totalrundelay = 0;
    for ($cpu = 0; $cpu <= $max_cpu; $cpu++) {
	@arr = @{$per_cpu_diff[$cpu]};
	if ($arr[$CPU_TRIPCNT] && ($arr[$CPU_CPUTIME] || $arr[$CPU_RUNDELAY])) {
	    $totalcpu += $arr[$CPU_CPUTIME];
	    $totaltripcnt += $arr[$CPU_TRIPCNT];
	    $totalrundelay += $arr[$CPU_RUNDELAY];
	    if ($opt_c) {
		printf "    %6.2f/%-6.2f    avg runtime/latency on cpu %d (ms)\n",
		    $arr[$CPU_CPUTIME]/$arr[$CPU_TRIPCNT],
		    $arr[$CPU_RUNDELAY]/$arr[$CPU_TRIPCNT], $cpu;
	    }
	}
    }
    printf "    %6.2f/%-6.2f    avg runtime/latency over all cpus (ms)\n",
	$totalcpu/$totaltripcnt, $totalrundelay/$totaltripcnt;

    printf("\n");

    #
    # domain info
    #
    if ($opt_d) {
	foreach $domain (0..$max_domain) {
	    $domain_diff = $diff[13+$domain];
	    #print "  domain$domain @{$domain_diff}\n";
	    print "[scheduler domain #$domain]\n";

	    $pt_cnt_total = $domain_diff->[$PT_CNT_IDLE] +
		$domain_diff->[$PT_CNT_NEWIDLE] + $domain_diff->[$PT_CNT_NOIDLE];
	    printf "    %7d          tasks pulled by pull_task()\n", $pt_cnt_total;
	    printf "    %7d(%6.2f%%) pulled from hot cpu while still cache-hot and idle\n",
		$domain_diff->[$PT_HOT_IDLE],
		100*$domain_diff->[$PT_HOT_IDLE]/$pt_cnt_total
		if ($domain_diff->[$PT_HOT_IDLE]);
	    printf "    %7d(%6.2f%%) pulled from cold cpu while idle\n",
		$domain_diff->[$PT_CNT_IDLE] - $domain_diff->[$PT_HOT_IDLE],
		100*($domain_diff->[$PT_CNT_IDLE] - $domain_diff->[$PT_HOT_IDLE])/$pt_cnt_total
		if ($domain_diff->[$PT_CNT_IDLE] - $domain_diff->[$PT_HOT_IDLE]);
	    printf "    %7d(%6.2f%%) pulled from hot cpu while still cache-hot and busy\n",
		$domain_diff->[$PT_HOT_NOIDLE],
		100*$domain_diff->[$PT_HOT_NOIDLE]/$pt_cnt_total
		if ($domain_diff->[$PT_HOT_NOIDLE]);
	    printf "    %7d(%6.2f%%) pulled from cold cpu while busy\n",
		$domain_diff->[$PT_CNT_NOIDLE] - $domain_diff->[$PT_HOT_NOIDLE],
		100*($domain_diff->[$PT_CNT_NOIDLE] - $domain_diff->[$PT_HOT_NOIDLE])/$pt_cnt_total
		if ($domain_diff->[$PT_CNT_NOIDLE] - $domain_diff->[$PT_HOT_NOIDLE]);
	    printf "    %7d(%6.2f%%) pulled from hot cpu while still cache-hot and newly idle\n",
		$domain_diff->[$PT_HOT_NEWIDLE],
		100*$domain_diff->[$PT_HOT_NEWIDLE]/$pt_cnt_total
		if ($domain_diff->[$PT_HOT_NEWIDLE]);
	    printf "    %7d(%6.2f%%) pulled from cold cpu when newly idle\n",
		$domain_diff->[$PT_CNT_NEWIDLE] - $domain_diff->[$PT_HOT_NEWIDLE],
		100*($domain_diff->[$PT_CNT_NEWIDLE] - $domain_diff->[$PT_HOT_NEWIDLE])/$pt_cnt_total
		if ($domain_diff->[$PT_CNT_NEWIDLE] - $domain_diff->[$PT_HOT_NEWIDLE]);

	    #
	    # load_balance() stats
	    #
	    $lb_cnt_total = $domain_diff->[$LB_CNT_IDLE] +
		$domain_diff->[$LB_CNT_NEWIDLE] + $domain_diff->[$LB_CNT_NOIDLE];

	    printf "\n    %7d          load_balance()\n", $lb_cnt_total;

	    #
	    # while idle
	    #
	    printf "    %7d(%6.2f%%) called while idle\n",
		$domain_diff->[$LB_CNT_IDLE],
		$lb_cnt_total ?  100*$domain_diff->[$LB_CNT_IDLE]/$lb_cnt_total : 0;
	    printf "                     %7d(%6.2f%%) tried but failed to move any tasks\n",
		$domain_diff->[$LB_FAILED_IDLE],
		$domain_diff->[$LB_CNT_IDLE] ?
		    100*$domain_diff->[$LB_FAILED_IDLE]/$domain_diff->[$LB_CNT_IDLE] :
		    0
		if ($domain_diff->[$LB_FAILED_IDLE]);
	    printf "                     %7d(%6.2f%%) found no busier queue\n",
		$domain_diff->[$LB_NOBUSYQ_IDLE],
		$domain_diff->[$LB_CNT_IDLE] ?
		    100*$domain_diff->[$LB_NOBUSYQ_IDLE]/$domain_diff->[$LB_CNT_IDLE] :
		    0
		if ($domain_diff->[$LB_NOBUSYQ_IDLE]);
	    printf "                     %7d(%6.2f%%) found no busier group\n",
		$domain_diff->[$LB_NOBUSYG_IDLE],
		$domain_diff->[$LB_CNT_IDLE] ?
		    100*$domain_diff->[$LB_NOBUSYG_IDLE]/$domain_diff->[$LB_CNT_IDLE] :
		    0
		if ($domain_diff->[$LB_NOBUSYG_IDLE]);
	    $tmp = $domain_diff->[$LB_CNT_IDLE] -
		($domain_diff->[$LB_NOBUSYG_IDLE] + $domain_diff->[$LB_NOBUSYQ_IDLE] +
		$domain_diff->[$LB_FAILED_IDLE]);
	    if ($tmp) {
		printf "                     %7d(%6.2f%%) succeeded in moving " .
		    "at least one task\n",
		    $tmp, $tmp ?  100*$tmp/$domain_diff->[$LB_CNT_IDLE] : 0;
		$imbalance = $domain_diff->[$LB_IMBALANCE_IDLE] /
		    ($tmp + $domain_diff->[$LB_FAILED_IDLE]);
		if ($imbalance < 10) {
		    $fmt = "%7.3f";
		} elsif ($imbalance < 100) {
		    $fmt = "%7.2f";
		} else {
		    $fmt = "%7.1f";
		}
		printf "                                      (average imbalance: $fmt)\n",
		    $imbalance;
	    }

	    #
	    # while busy
	    #
	    printf "    %7d(%6.2f%%) called while busy\n",
		$domain_diff->[$LB_CNT_NOIDLE],
		$lb_cnt_total ?  100*$domain_diff->[$LB_CNT_NOIDLE]/$lb_cnt_total : 0;
	    printf "                     %7d(%6.2f%%) tried but failed to move any tasks\n",
		$domain_diff->[$LB_FAILED_NOIDLE],
		$domain_diff->[$LB_CNT_NOIDLE] ?
		    100*$domain_diff->[$LB_FAILED_NOIDLE]/$domain_diff->[$LB_CNT_NOIDLE] :
		    0
		if ($domain_diff->[$LB_FAILED_NOIDLE]);
	    printf "                     %7d(%6.2f%%) found no busier queue\n",
		$domain_diff->[$LB_NOBUSYQ_NOIDLE],
		$domain_diff->[$LB_CNT_NOIDLE] ?
		    100*$domain_diff->[$LB_NOBUSYQ_NOIDLE]/$domain_diff->[$LB_CNT_NOIDLE] :
		    0
		if ($domain_diff->[$LB_NOBUSYQ_NOIDLE]);
	    printf "                     %7d(%6.2f%%) found no busier group\n",
		$domain_diff->[$LB_NOBUSYG_NOIDLE],
		$domain_diff->[$LB_CNT_NOIDLE] ?
		    100*$domain_diff->[$LB_NOBUSYG_NOIDLE]/$domain_diff->[$LB_CNT_NOIDLE] :
		    0
		if ($domain_diff->[$LB_NOBUSYG_NOIDLE]);
	    $tmp = $domain_diff->[$LB_CNT_NOIDLE] -
		($domain_diff->[$LB_NOBUSYG_NOIDLE] +
		$domain_diff->[$LB_NOBUSYQ_NOIDLE] +
		$domain_diff->[$LB_FAILED_NOIDLE]);
	    if ($tmp) {
		printf "                     %7d(%6.2f%%) succeeded in moving " .
		    "at least one task\n",
		    $tmp, $tmp ?  100*$tmp/$domain_diff->[$LB_CNT_NOIDLE] : 0;
		$imbalance = $domain_diff->[$LB_IMBALANCE_NOIDLE] /
		    ($tmp + $domain_diff->[$LB_FAILED_NOIDLE]);
		if ($imbalance < 10) {
		    $fmt = "%7.3f";
		} elsif ($imbalance < 100) {
		    $fmt = "%7.2f";
		} else {
		    $fmt = "%7.1f";
		}
		printf "                                      (average imbalance: $fmt)\n",
		    $imbalance;
	    }


	    #
	    # when newly idle
	    #
	    printf "    %7d(%6.2f%%) called when newly idle\n",
		$domain_diff->[$LB_CNT_NEWIDLE],
		$lb_cnt_total ?  100*$domain_diff->[$LB_CNT_NEWIDLE]/$lb_cnt_total
		: 0;
	    printf "                     %7d(%6.2f%%) tried but failed to move any tasks\n",
		$domain_diff->[$LB_FAILED_NEWIDLE],
		$domain_diff->[$LB_CNT_NEWIDLE] ?
		    100*$domain_diff->[$LB_FAILED_NEWIDLE]/$domain_diff->[$LB_CNT_NEWIDLE] :
		    0
		if ($domain_diff->[$LB_FAILED_NEWIDLE]);
	    printf "                     %7d(%6.2f%%) found no busier queue\n",
		$domain_diff->[$LB_NOBUSYQ_NEWIDLE],
		$domain_diff->[$LB_CNT_NEWIDLE] ?
		    100*$domain_diff->[$LB_NOBUSYQ_NEWIDLE]/$domain_diff->[$LB_CNT_NEWIDLE] :
		    0
		if ($domain_diff->[$LB_NOBUSYQ_NEWIDLE]);
	    printf "                     %7d(%6.2f%%) found no busier group\n",
		$domain_diff->[$LB_NOBUSYG_NEWIDLE],
		$domain_diff->[$LB_CNT_NEWIDLE] ?
		    100*$domain_diff->[$LB_NOBUSYG_NEWIDLE]/$domain_diff->[$LB_CNT_NEWIDLE] :
		    0
		if ($domain_diff->[$LB_NOBUSYG_NEWIDLE]);
	    $tmp = $domain_diff->[$LB_CNT_NEWIDLE] -
		($domain_diff->[$LB_NOBUSYG_NEWIDLE] +
		$domain_diff->[$LB_NOBUSYQ_NEWIDLE] +
		$domain_diff->[$LB_FAILED_NEWIDLE]);
	    if ($tmp) {
		printf "                     %7d(%6.2f%%) succeeded in moving " .
		    "at least one task\n",
		    $tmp, $tmp ?  100*$tmp/$domain_diff->[$LB_CNT_NEWIDLE] : 0;
		$imbalance = $domain_diff->[$LB_IMBALANCE_NEWIDLE] /
		    ($tmp + $domain_diff->[$LB_FAILED_NEWIDLE]);
		if ($imbalance < 10) {
		    $fmt = "%7.3f";
		} elsif ($imbalance < 100) {
		    $fmt = "%7.2f";
		} else {
		    $fmt = "%7.1f";
		}
		printf "                                      (average imbalance: $fmt)\n",
		    $imbalance;
	    }

	    #
	    # active_load_balance() stats
	    #
	    printf "\n    %7d          active_load_balance() was called\n",
		$domain_diff->[$ALB_CNT];
	    printf "    %7d          active_load_balance() tried to push a task\n",
		$domain_diff->[$ALB_PUSHED] + $domain_diff->[$ALB_FAILED]
		if ($domain_diff->[$ALB_PUSHED] || $domain_diff->[$ALB_FAILED]);
	    printf "    %7d          active_load_balance() succeeded in pushing a task\n",
		$domain_diff->[$ALB_PUSHED] if ($domain_diff->[$ALB_PUSHED]);

	    #
	    # try_to_wake_up() stats
	    #
	    printf "\n                     try_to_wake_up() ...\n"
		if ($domain_diff->[$TTWU_WAKE_REMOTE]);
	    printf "    %7d          ... found that the task being awakened was last on different cpu than waker\n",
		$domain_diff->[$TTWU_WAKE_REMOTE]
		if ($domain_diff->[$TTWU_WAKE_REMOTE]);
	    printf "    %7d(%6.2f%%) ... moved that task to the waking cpu because it was cache-cold\n",
		$domain_diff->[$TTWU_MOVE_AFFINE],
		100*$domain_diff->[$TTWU_MOVE_AFFINE]/$domain_diff->[$TTWU_WAKE_REMOTE]
		if ($domain_diff->[$TTWU_MOVE_AFFINE]);
	    printf "    %7d(%6.2f%%) ... moved that task to the waking cpu because the cpu's queue was unbalanced\n",
		$domain_diff->[$TTWU_MOVE_BALANCE],
		100*$domain_diff->[$TTWU_MOVE_BALANCE]/$domain_diff->[$TTWU_WAKE_REMOTE]
		if ($domain_diff->[$TTWU_MOVE_BALANCE]);
	    printf "    %7d(%6.2f%%) ... didn't move that task\n",
		$domain_diff->[$TTWU_WAKE_REMOTE] -
		    $domain_diff->[$TTWU_MOVE_AFFINE] - $domain_diff->[$TTWU_MOVE_BALANCE],
		100*($domain_diff->[$TTWU_WAKE_REMOTE] -
		    $domain_diff->[$TTWU_MOVE_AFFINE] - $domain_diff->[$TTWU_MOVE_BALANCE])
		    / $domain_diff->[$TTWU_WAKE_REMOTE]
		if ($domain_diff->[$TTWU_WAKE_REMOTE] -
		    $domain_diff->[$TTWU_MOVE_AFFINE] -
		    $domain_diff->[$TTWU_MOVE_BALANCE]);
	    print "\n";
	}
    } else {
	#
	# pull_task() stats
	#
	$pt_cnt_total = $domain_diff_all[$PT_CNT_IDLE] +
	    $domain_diff_all[$PT_CNT_NEWIDLE] + $domain_diff_all[$PT_CNT_NOIDLE];
	printf "    %7d          tasks pulled by pull_task()\n", $pt_cnt_total;
	printf "    %7d(%6.2f%%) pulled from hot cpu while still cache-hot and idle\n",
	    $domain_diff_all[$PT_HOT_IDLE],
	    100*$domain_diff_all[$PT_HOT_IDLE]/$pt_cnt_total
	    if ($domain_diff_all[$PT_HOT_IDLE]);
	printf "    %7d(%6.2f%%) pulled from cold cpu while idle\n",
	    $domain_diff_all[$PT_CNT_IDLE] - $domain_diff_all[$PT_HOT_IDLE],
	    100*($domain_diff_all[$PT_CNT_IDLE] - $domain_diff_all[$PT_HOT_IDLE])/$pt_cnt_total
	    if ($domain_diff_all[$PT_CNT_IDLE] - $domain_diff_all[$PT_HOT_IDLE]);
	printf "    %7d(%6.2f%%) pulled from hot cpu while still cache-hot and busy\n",
	    $domain_diff_all[$PT_HOT_NOIDLE],
	    100*$domain_diff_all[$PT_HOT_NOIDLE]/$pt_cnt_total
	    if ($domain_diff_all[$PT_HOT_NOIDLE]);
	printf "    %7d(%6.2f%%) pulled from cold cpu while busy\n",
	    $domain_diff_all[$PT_CNT_NOIDLE] - $domain_diff_all[$PT_HOT_NOIDLE],
	    100*($domain_diff_all[$PT_CNT_NOIDLE] - $domain_diff_all[$PT_HOT_NOIDLE])/$pt_cnt_total
	    if ($domain_diff_all[$PT_CNT_NOIDLE] - $domain_diff_all[$PT_HOT_NOIDLE]);
	printf "    %7d(%6.2f%%) pulled from hot cpu while still cache-hot and newly idle\n",
	    $domain_diff_all[$PT_HOT_NEWIDLE],
	    100*$domain_diff_all[$PT_HOT_NEWIDLE]/$pt_cnt_total
	    if ($domain_diff_all[$PT_HOT_NEWIDLE]);
	printf "    %7d(%6.2f%%) pulled from cold cpu when newly idle\n",
	    $domain_diff_all[$PT_CNT_NEWIDLE] - $domain_diff_all[$PT_HOT_NEWIDLE],
	    100*($domain_diff_all[$PT_CNT_NEWIDLE] - $domain_diff_all[$PT_HOT_NEWIDLE])/$pt_cnt_total
	    if ($domain_diff_all[$PT_CNT_NEWIDLE] - $domain_diff_all[$PT_HOT_NEWIDLE]);

	#
	# load_balance() stats
	#
	$lb_cnt_total = $domain_diff_all[$LB_CNT_IDLE] +
	    $domain_diff_all[$LB_CNT_NEWIDLE] +
	    $domain_diff_all[$LB_CNT_NOIDLE];
	printf "\n    %7d          load_balance()\n", $lb_cnt_total;

	#
	# while idle
	#
	printf "    %7d(%6.2f%%) called while idle\n",
	    $domain_diff_all[$LB_CNT_IDLE],
	    $lb_cnt_total ?
		100*$domain_diff_all[$LB_CNT_IDLE]/$lb_cnt_total : 0;
	printf "                     %7d(%6.2f%%) tried but failed to move any tasks\n",
	    $domain_diff_all[$LB_FAILED_IDLE],
	    $domain_diff_all[$LB_CNT_IDLE] ?
		100*$domain_diff_all[$LB_FAILED_IDLE]/$domain_diff_all[$LB_CNT_IDLE] :
		0
	    if ($domain_diff_all[$LB_FAILED_IDLE]);
	printf "                     %7d(%6.2f%%) found no busier queue\n",
	    $domain_diff_all[$LB_NOBUSYQ_IDLE],
	    $domain_diff_all[$LB_CNT_IDLE] ?
		100*$domain_diff_all[$LB_NOBUSYQ_IDLE]/$domain_diff_all[$LB_CNT_IDLE] :
		0
	    if ($domain_diff_all[$LB_NOBUSYQ_IDLE]);
	printf "                     %7d(%6.2f%%) found no busier group\n",
	    $domain_diff_all[$LB_NOBUSYG_IDLE],
	    $domain_diff_all[$LB_CNT_IDLE] ?
		100*$domain_diff_all[$LB_NOBUSYG_IDLE]/$domain_diff_all[$LB_CNT_IDLE] :
		0
	    if ($domain_diff_all[$LB_NOBUSYG_IDLE]);
	$tmp = $domain_diff_all[$LB_CNT_IDLE] -
	    ($domain_diff_all[$LB_NOBUSYG_IDLE] + $domain_diff_all[$LB_NOBUSYQ_IDLE] +
	    $domain_diff_all[$LB_FAILED_IDLE]);
	if ($tmp) {
	    printf "                     %7d(%6.2f%%) succeeded in moving " .
		"at least one task\n",
		$tmp, $tmp ?  100*$tmp/$domain_diff_all[$LB_CNT_IDLE] : 0;
	    $imbalance = $domain_diff_all[$LB_IMBALANCE_IDLE] /
		($tmp + $domain_diff_all[$LB_FAILED_IDLE]);
	    if ($imbalance < 10) {
		$fmt = "%7.3f";
	    } elsif ($imbalance < 100) {
		$fmt = "%7.2f";
	    } else {
		$fmt = "%7.1f";
	    }
	    printf "                                      (average imbalance: $fmt)\n",
		$imbalance;
	}

	#
	# while busy
	#
	printf "    %7d(%6.2f%%) called while busy\n",
	    $domain_diff_all[$LB_CNT_NOIDLE],
	    $lb_cnt_total ?  100*$domain_diff_all[$LB_CNT_NOIDLE]/$lb_cnt_total : 0;
	printf "                     %7d(%6.2f%%) tried but failed to move any tasks\n",
	    $domain_diff_all[$LB_FAILED_NOIDLE],
	    $domain_diff_all[$LB_CNT_NOIDLE] ?
		100*$domain_diff_all[$LB_FAILED_NOIDLE]/$domain_diff_all[$LB_CNT_NOIDLE] :
		0
	    if ($domain_diff_all[$LB_FAILED_NOIDLE]);
	printf "                     %7d(%6.2f%%) found no busier queue\n",
	    $domain_diff_all[$LB_NOBUSYQ_NOIDLE],
	    $domain_diff_all[$LB_CNT_NOIDLE] ?
		100*$domain_diff_all[$LB_NOBUSYQ_NOIDLE]/$domain_diff_all[$LB_CNT_NOIDLE] :
		0
	    if ($domain_diff_all[$LB_NOBUSYQ_NOIDLE]);
	printf "                     %7d(%6.2f%%) found no busier group\n",
	    $domain_diff_all[$LB_NOBUSYG_NOIDLE],
	    $domain_diff_all[$LB_CNT_NOIDLE] ?
		100*$domain_diff_all[$LB_NOBUSYG_NOIDLE]/$domain_diff_all[$LB_CNT_NOIDLE] :
		0
	    if ($domain_diff_all[$LB_NOBUSYG_NOIDLE]);
	$tmp = $domain_diff_all[$LB_CNT_NOIDLE] -
	    ($domain_diff_all[$LB_NOBUSYG_NOIDLE] +
	    $domain_diff_all[$LB_NOBUSYQ_NOIDLE] +
	    $domain_diff_all[$LB_FAILED_NOIDLE]);
	if ($tmp) {
	    printf "                     %7d(%6.2f%%) succeeded in moving " .
		"at least one task\n",
		$tmp, $tmp ?  100*$tmp/$domain_diff_all[$LB_CNT_NOIDLE] : 0;
	    $imbalance = $domain_diff_all[$LB_IMBALANCE_NOIDLE] /
		($tmp + $domain_diff_all[$LB_FAILED_NOIDLE]);
	    if ($imbalance < 10) {
		$fmt = "%7.3f";
	    } elsif ($imbalance < 100) {
		$fmt = "%7.2f";
	    } else {
		$fmt = "%7.1f";
	    }
	    printf "                                      (average imbalance: $fmt)\n",
		$imbalance;
	}


	#
	# when newly idle
	#
	printf "    %7d(%6.2f%%) called when newly idle\n",
	    $domain_diff_all[$LB_CNT_NEWIDLE],
	    $lb_cnt_total ?  100*$domain_diff_all[$LB_CNT_NEWIDLE]/$lb_cnt_total
	    : 0;
	printf "                     %7d(%6.2f%%) tried but failed to move any tasks\n",
	    $domain_diff_all[$LB_FAILED_NEWIDLE],
	    $domain_diff_all[$LB_CNT_NEWIDLE] ?
		100*$domain_diff_all[$LB_FAILED_NEWIDLE]/$domain_diff_all[$LB_CNT_NEWIDLE] :
		0
	    if ($domain_diff_all[$LB_FAILED_NEWIDLE]);
	printf "                     %7d(%6.2f%%) found no busier queue\n",
	    $domain_diff_all[$LB_NOBUSYQ_NEWIDLE],
	    $domain_diff_all[$LB_CNT_NEWIDLE] ?
		100*$domain_diff_all[$LB_NOBUSYQ_NEWIDLE]/$domain_diff_all[$LB_CNT_NEWIDLE] :
		0
	    if ($domain_diff_all[$LB_NOBUSYQ_NEWIDLE]);
	printf "                     %7d(%6.2f%%) found no busier group\n",
	    $domain_diff_all[$LB_NOBUSYG_NEWIDLE],
	    $domain_diff_all[$LB_CNT_NEWIDLE] ?
		100*$domain_diff_all[$LB_NOBUSYG_NEWIDLE]/$domain_diff_all[$LB_CNT_NEWIDLE] :
		0
	    if ($domain_diff_all[$LB_NOBUSYG_NEWIDLE]);
	$tmp = $domain_diff_all[$LB_CNT_NEWIDLE] -
	    ($domain_diff_all[$LB_NOBUSYG_NEWIDLE] +
	    $domain_diff_all[$LB_NOBUSYQ_NEWIDLE] +
	    $domain_diff_all[$LB_FAILED_NEWIDLE]);
	if ($tmp) {
	    printf "                     %7d(%6.2f%%) succeeded in moving " .
		"at least one task\n",
		$tmp, $tmp ?  100*$tmp/$domain_diff_all[$LB_CNT_NEWIDLE] : 0;
	    $imbalance = $domain_diff_all[$LB_IMBALANCE_NEWIDLE] /
		($tmp + $domain_diff_all[$LB_FAILED_NEWIDLE]);
	    if ($imbalance < 10) {
		$fmt = "%7.3f";
	    } elsif ($imbalance < 100) {
		$fmt = "%7.2f";
	    } else {
		$fmt = "%7.1f";
	    }
	    printf "                                      (average imbalance: $fmt)\n",
		$imbalance;
	}

	#
	# active_load_balance() stats
	#
	printf "\n    %7d          active_load_balance() was called\n",
	    $domain_diff_all[$ALB_CNT];
	printf "    %7d          active_load_balance() tried to push a task\n",
	    $domain_diff_all[$ALB_PUSHED] + $domain_diff_all[$ALB_FAILED]
	    if ($domain_diff_all[$ALB_PUSHED] || $domain_diff_all[$ALB_FAILED]);
	printf "    %7d          active_load_balance() succeeded in pushing a task\n",
	    $domain_diff_all[$ALB_PUSHED]
	    if ($domain_diff_all[$ALB_PUSHED]);

	print "\n";
    }
}
