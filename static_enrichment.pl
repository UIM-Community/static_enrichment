use strict;
use warnings;
use lib "E:/Nimsoft/perllib";
use Data::Dumper;
$Data::Dumper::Deparse = 1;
use threads;
use Thread::Queue;
use threads::shared;
use Nimbus::API;
use Nimbus::PDS;
use Lib::enrichment_rule;
use Perluim::API;
use Perluim::Addons::CFGManager;

# Global variables
$Perluim::API::Debug = 1;
my ($STR_Login,$STR_Password,$STR_NIMDomain,$BOOL_DEBUG,$STR_NBThreads,$BOOL_ExclusiveEnrichment,$INT_Interval,$INT_Logsize,$INT_Heartbeat,$INT_QOS);
my ($ALM_Sev,$ALM_Subsys,$ALM_Suppkey,$ALM_Message);
my ($STR_ReadSubject,$STR_PostSubject);
my $HASH_Robot;
my $AlarmHandled = 0;
my $AlarmProcessed : shared = 0;
my $Probe_NAME  = "static_enrichment";
my $Probe_VER   = "1.0";
my $Probe_CFG   = "static_enrichment.cfg";
my $T_Heartbeat = nimTimerCreate(); 
my $T_QOS       = nimTimerCreate(); 
nimTimerStart($T_Heartbeat);
nimTimerStart($T_QOS);
$SIG{__DIE__} = \&scriptDieHandler;

#
# Register logger!
# 
my $Logger = uimLogger({
    file => "static_enrichment.log",
    level => 3
});
my @EnrichmentRules = ();
$Logger->info("Probe $Probe_NAME initialized, version => $Probe_VER");

#
# scriptDieHandler
#
sub scriptDieHandler {
    my ($err) = @_; 
    print "$err";
    $Logger->fatal($err);
    exit(1);
}

use constant {
    PDS_PPCH => 8,
    PDS_PPI => 3,
    PDS_PPDS => 24
};

sub asHash {
    my $pds  = shift;
    my $lev  = shift || 1;
    my ($rc, $k, $t, $s, $d);
    my $hptr = {};
    my $line = "-"x$lev;

    while ($rc == 0) {
        ($rc, $k, $t, $s, $d) = pdsGetNext($pds);
        next if $rc != PDS_ERR_NONE;

        if ($t == PDS_PDS) {
            if (!defined($hptr->{$k})) {
                nimLog(2,"PDS::asHash $line>Adding PDS: $k\n");
                $hptr->{$k}={};
            }
            asHash($self,$hptr->{$k},$d,$lev+1);
            pdsDelete($d);
        }
        elsif ($t == PDS_PPCH || $t == PDS_PPI) {
            nimLog(2,"PDS::asHash $line>Adding PDS_PPCH/PDS_PPI Array: $key\n");
            my @ret = ();
            for (my $index = 0; my ($rc_table, $rd) = pdsGetTable($pds, PDS_PCH, $k, $index); $index++) {
                last if $rc_table != PDS_ERR_NONE;
                push(@ret, $rd);
            }
            $hptr->{$k} = \@ret;
        }
        elsif ($t == PDS_PPDS) {
            nimLog(2,"PDS::asHash $line>Adding PDS_PPDS Array: $key\n");
            my @ret = ();
            for (my $index = 0; my ($rc_table, $rd) = pdsGetTable($pds, PDS_PDS, $k, $index); $index++) {
                last if $rc_table != PDS_ERR_NONE;
                push(@ret, Nimbus::PDS->new($rd)->asHash);
            }
            $hptr->{$k} = \@ret;
        }
        else {
            nimLog(2,"PDS::asHash $line>Adding key/value: $k = $d");
            $hptr->{$k} = $d;
        }
    };

    return $hptr;
}

#
# Init and configuration configuration
#
sub read_configuration {
    $Logger->nolevel("---------------------------------");
    $Logger->info("Read and parse configuration file!");
    my $CFGManager = Perluim::Addons::CFGManager->new($Probe_CFG,1);

    $CFGManager->setSection("setup");
    $BOOL_DEBUG              = $CFGManager->get("debug",0);
    $Logger->setLevel($CFGManager->get("loglevel",5));
    $Logger->trace($CFGManager) if $BOOL_DEBUG;

    $STR_Login               = $CFGManager->get("login","administrator");
    $STR_Password            = $CFGManager->get("password");
    $INT_Logsize             = $CFGManager->get("logsize",1024);
    $STR_ReadSubject         = $CFGManager->get("queue_attach",$Probe_NAME);
    $STR_PostSubject         = $CFGManager->get("post_subject");
    $STR_NBThreads           = $CFGManager->get("pool_threads",10);
    $INT_Heartbeat           = $CFGManager->get("heartbeat",300);
    $INT_QOS                 = $CFGManager->get("qos",300);
    $INT_Interval            = $CFGManager->get("timeout_interval",30000);
    $Logger->setSize($INT_Logsize);
    $Logger->truncate();

    $CFGManager->setSection("messages/heartbeat");
    $ALM_Sev        = $CFGManager->get("severity",2);
    $ALM_Subsys     = $CFGManager->get("subsys","1.1");
    $ALM_Message    = $CFGManager->get('message','static_enrichment heartbeat!');
    $ALM_Suppkey    = $CFGManager->get("suppkey","${Probe_NAME}_alarm_processed");

    @EnrichmentRules = ();
    $CFGManager->setSection("enrichment-rules");
    $BOOL_ExclusiveEnrichment = $CFGManager->get("exclusive_enrichment","no");

    my $Rules = $CFGManager->listSections("enrichment-rules");
    foreach my $RuleSection (@$Rules) {
        $CFGManager->setSection($RuleSection);
        my $match_alarm_field   = $CFGManager->get("match_alarm_field");
        my $match_alarm_regexp  = $CFGManager->get("match_alarm_regexp");
        my $fallback_value  = $CFGManager->get("fallback_value", "");
        if(defined $match_alarm_field && defined $match_alarm_regexp) {
            my %OverwriteHash = ();
            $CFGManager->setSection("$RuleSection/overwrite-rules");
            my $OWKeys = $CFGManager->listKeys("$RuleSection/overwrite-rules");
            foreach my $K (@$OWKeys) {
                my $V = $CFGManager->get($K);
                next if !defined $V;
                $OverwriteHash{$K} = $V;
            }
            if(scalar keys %OverwriteHash > 0) {
                push(@EnrichmentRules,Lib::enrichment_rule->new({
                    name => $RuleSection,
                    fallbackValue => $fallback_value,
                    field => $match_alarm_field,
                    regexp => qr/$match_alarm_regexp/,
                    overwrite => \%OverwriteHash
                }));
            }
            else {
                $Logger->warn("No overwrite rules detected for $RuleSection...");
            }
        }
        else {
            $Logger->error("Please configure $RuleSection correctly!");
        }
    }

    $Lib::enrichment_rule::Logger = $Logger;

    # Send QOS Definition to data_engine probe
    nimQoSSendDefinition("QOS_StaticEnrichment","QOS_StaticEnrichment","Static enrichment alarms stats","s",NIMQOS_DEF_NONE);
    $Logger->nolevel("---------------------------------");
}
read_configuration();

# Login to Nimbus!
nimLogin("$STR_Login","$STR_Password") if defined $STR_Login && defined $STR_Password;

# Find Nimsoft Domain!
$Logger->info("Get nimsoft domain...");
{
    my ($RC,$STR_Domain) = nimGetVarStr(NIMV_HUBDOMAIN);
    scriptDieHandler("Failed to get domain!") if $RC != NIME_OK;
    $STR_NIMDomain = $STR_Domain;
}

$Logger->info("DOMAIN => $STR_NIMDomain");

# Get local robot info ! 
{
    my ($request,$response);
    $request = uimRequest({
        addr => "controller",
        callback => "get_info",
        retry => 3,
        timeout => 5
    });
    $response = $request->send(1);
    scriptDieHandler("Failed to get information for local robot") if not $response->rc(NIME_OK);
    $HASH_Robot = $response->hashData();
}

# Echo information about the robot where the script is started!
$Logger->info("HUBNAME => $HASH_Robot->{hubname}");
$Logger->info("ROBOTNAME => $HASH_Robot->{robotname}");
$Logger->info("VERSION => $HASH_Robot->{version}");
$Logger->nolevel("--------------------------------");

sub GenerateAlarm {
    my ($PDSHash) = @_;
    if(defined $PDSHash->{os_user1}) {
        $PDSHash->{user_tag_1} = $PDSHash->{os_user1};
        delete $PDSHash->{os_user1};
    }
    if(defined $PDSHash->{os_user2}) {
        $PDSHash->{user_tag_2} = $PDSHash->{os_user2};
        delete $PDSHash->{os_user2};
    }
    my $alarmID = nimId();
    my $PDS     = pdsFromHash($PDSHash);
    $PDS->string('subject',$STR_PostSubject);
    $PDS->string('nimid',$alarmID);
    $Logger->log(1,"Post new alarm $alarmID from $HASH_Robot->{robotname} to spooler!");
    my ($RC,$RES) = nimRequest("$HASH_Robot->{robotname}",48001,"post_raw",$PDS->data);
    $Logger->log(1,"Failed to send alarm => ".nimError2Txt($RC)) if $RC != NIME_OK;
}

my $handleAlarm;
my $alarmQueue = Thread::Queue->new();
$handleAlarm = sub {
    $Logger->info("Thread started!");
    while ( defined ( my $PDSHash = $alarmQueue->dequeue() ) ) {
        if ($BOOL_DEBUG) {
            $Logger->info(Dumper($PDSHash));
        }
        my $enriched = 0;
        foreach(@EnrichmentRules) {
            ($PDSHash,$enriched) = $_->processAlarm($PDSHash);
            last if $enriched && $BOOL_ExclusiveEnrichment eq "yes";
        }
        GenerateAlarm($PDSHash);
        lock($AlarmProcessed);
        $AlarmProcessed++;
    }
    $Logger->info("Thread finished!");
};

# Wait for group threads
my @thr = map {
    threads->create(\&$handleAlarm);
} 1..$STR_NBThreads;
$_->detach() for @thr;

#
# Register probe
# 
my $probe = uimProbe({
    name    => $Probe_NAME,
    version => $Probe_VER,
    timeout => $INT_Interval
});
$Logger->trace($probe);

# Register callbacks (String and Int are valid type for arguments)
$Logger->info("Register probe callbacks...");
$probe->registerCallback( "get_info" );

# Probe restarted
$probe->on( restart => sub {
    $Logger->log(0,"Probe restarted");
    read_configuration();
});

# Probe timeout
$probe->on( timeout => sub {
    eval {
        $Logger->truncate();
    };
    $Logger->error($@) if $@;
    $Logger->log(1,"Alarms handled => $AlarmHandled");
    $Logger->log(1,"Alarms enriched => $AlarmProcessed");

    my ($T_HeartbeatDiff) = nimTimerDiffSec($T_Heartbeat);
    if($T_HeartbeatDiff > $INT_Heartbeat) {
        $Logger->log(1,"Launch heartbeat alarm!!");
        $T_Heartbeat = nimTimerCreate();
        my %AlarmObject = (
            severity    => $ALM_Sev,
            message     => $ALM_Message,
            robot       => $HASH_Robot->{robotname},
            domain      => $STR_NIMDomain,
            probe       => $Probe_NAME,
            origin      => $HASH_Robot->{origin},
            source      => $HASH_Robot->{robotip},
            dev_id      => $HASH_Robot->{robot_device_id},
            subsystem   => $ALM_Subsys,
            suppression => $ALM_Suppkey,
            supp_key    => $ALM_Suppkey,
            usertag1    => $HASH_Robot->{os_user1},
            usertag2    => $HASH_Robot->{os_user2}
        );
        my ($PDS,$alarmid) = generateAlarm('alarm',\%AlarmObject);
        $Logger->warn("New alarm generate with id => $alarmid");
        my ($rc_alarm,$res) = nimRequest("$HASH_Robot->{robotname}",48001,"post_raw",$PDS->data);

        $Logger->info("Alarm sent successfully!") if $rc_alarm == NIME_OK;
        $Logger->error("Failed to sent new alarm! RC => $rc_alarm") if $rc_alarm != NIME_OK;
        nimTimerStart($T_Heartbeat);
    }
    undef $T_HeartbeatDiff;

    my ($T_QOSDiff) = nimTimerDiffSec($T_QOS);
    if($T_QOSDiff > $INT_QOS) {
        $Logger->log(1,"Launch QOS!!");
        $T_QOS = nimTimerCreate();
        my $NIMQOS = nimQoSCreate("QOS_StaticEnrichment",$HASH_Robot->{robotname},$INT_QOS,-1);
        nimQoSSendValue($NIMQOS,"alarm_handle",$AlarmHandled);
        nimQoSSendValue($NIMQOS,"alarm_processed",$AlarmProcessed);
        $AlarmHandled = 0;
        $AlarmProcessed = 0;
        nimQoSFree($NIMQOS);
        nimTimerStart($T_QOS);
    }
});

# Hubpost handle!
sub hubpost {
    my ($hMsg, $udata, $full) = @_;
    $alarmQueue->enqueue(asHash($full));
    $AlarmHandled++;
    nimSendReply($hMsg);
}

# Start probe!
$probe->attach($STR_ReadSubject);
$probe->start;
$Logger->nolevel("--------------------------------");

#
# get_info callback!
#
sub get_info {
    my ($hMsg) = @_;
    $Logger->log(0, "get_info callback triggered !");
    nimSendReply($hMsg, NIME_OK);
}
