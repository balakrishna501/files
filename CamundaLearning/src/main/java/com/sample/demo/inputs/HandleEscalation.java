package com.sample.demo.inputs;

import io.camunda.client.annotation.JobWorker;
import io.camunda.client.api.response.ActivatedJob;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class HandleEscalation {

    private final static Logger LOG = LoggerFactory.getLogger(HandleEscalation.class);
    @JobWorker(name = "handleEscalation")
    public void handleEscalation(final ActivatedJob job){
        LOG.info("handleEscalation job triggered");
    }
}