> This probe is under GNU licence, all right reserved NEURONES IT - 205 Avenue Georges Clemenceau, 92000 Nanterre

# Static_enrichment
CA UIM - Static message enrichment

This probe is designed to enrich alarm statically by matching a single field with a perl regexp. All messages are handled in a multithread pool to allow the maximum performance possible.

The probe attach to a queue namned '**static_enrichment**'.

# Benchmark 

When generate_new_alarm is set '**no**' : 

- A single thread can take around 50,000 messages every seconds (with one rule).

When generate new_alarm is set '**yes**' : 

- A single thread can take around 340 messages every seconds (with one rule).

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
    qos = 300 <!-- QoS (alarm_processed - alarm_handled) interval in second -->
    <!-- login = administrator -->
    <!-- password = password -->
</setup>
<!-- 
    Every rule are processed in order for every message. So enrichment rule can be cascaded if exclusive_enrichment stay to 'no'.
-->
<enrichment-rules>
    exclusive_enrichment = no <!-- if yes: break the processing on the first enrichment rule matched, so only one enrichment will by applied by message -->
    generate_new_alarm = no <!-- Publish a new complete alarm, allow to update other field than udata but have a high performance cost -->
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
            origin = OVERWRITED <!-- only if generate_new_alarm is set to yes -->
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