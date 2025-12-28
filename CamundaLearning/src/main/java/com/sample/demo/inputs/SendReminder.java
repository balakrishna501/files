package com.sample.demo.inputs;

import io.camunda.client.annotation.JobWorker;
import io.camunda.client.api.response.ActivatedJob;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class SendReminder {

    private final static Logger LOG = LoggerFactory.getLogger(SendReminder.class);
    @JobWorker(name = "sendReminder")
    public void sendReminder(final ActivatedJob job){
        LOG.info("SendReminder job triggered");
    }
}