# Static_enrichment
CA UIM - Static message enrichment

This probe is designed to enrich alarm statically by matching a single field with a perl regexp. All messages are handled in a multithread pool to allow the maximum performance possible.

The probe will attach to a queue namned '**static_enrichment**'. This queue can be overwritted with the configuration key setup/queue_attach.

> Warning: Dont configure this probe with to much threads and stay resonnable on the queue bulk_size. This script is capable to process hundreds of thousands of messages in less than one second (The hub will break because of the storm generated by the probe).

# Benchmark 

- A single thread can take around 400 alarms every seconds (with one rule).

# Configuration 

> field setup/login and setup/password **are only required when the script is executed in a terminal**.

```xml
<setup>
    loglevel = 1 <!-- classical nimsoft loglevel -->
    logsize = 1024 <!-- logsize in KB -->
    debug = 0 <!-- advanced debug mode -->
    post_subject = alarm2 <!-- subject where pds are posted when enrichment is done -->
    pool_threads = 3 <!-- number of threads in the pool -->
    timeout_interval = 5000 <!-- probe timeout interval, 5000 is ok -->
    heartbeat = 300 <!-- hearbeat alarm processed interval in second -->
    qos = 30 <!-- QoS (alarm_processed - alarm_handled) interval in second -->
    <!-- queue_attach = queueName -->
    <!-- login = administrator -->
    <!-- password = password -->
</setup>
<!-- 
    Every rule are processed in order for every message. So enrichment rule can be cascaded if exclusive_enrichment stay to 'no'.
-->
<enrichment-rules>
    exclusive_enrichment = no <!-- if yes: break the processing on the first enrichment rule matched, so only one enrichment will by applied by message -->
    <100> <!-- The name of your rule, put what you want like 'superRule' or 55 etc -->
        match_alarm_field = udata.level <!-- field to match -->
        match_alarm_regexp = 1 <!-- regexp (perl) -->
        <!--
            Field in alarm to overwrite OR to create.
            Add variable with the pattern < [] >.
            Example : my custom message [alarmvar]
        -->
        <overwrite-rules>
            udata.enriched = 0#[udata.subsys]#[supp_key] <!-- add a new field enriched -->
            udata.message = [supp_key] - [udata.message] <!-- re-write the message with the alarm supp_key in front -->
        </overwrite-rules>
    </100>
    <logmonAE> 
        match_alarm_field = prid 
        match_alarm_regexp = logmon
        <overwrite-rules>
            origin = OVERWRITED
            udata.message = #logmon - [udata.message]
        </overwrite-rules>
    </logmonAE>
</enrichment-rules>
<!-- 
    Alarms sections. Configure the severity, suppkey and subsystem id of every alarms.
-->
<messages>
    <heartbeat>
        severity = 5
        suppkey = test
        subsys = 1.1.
    </heartbeat>
</messages>
```
