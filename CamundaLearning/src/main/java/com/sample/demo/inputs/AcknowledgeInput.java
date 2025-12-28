package com.sample.demo.inputs;

import io.camunda.client.annotation.JobWorker;
import io.camunda.client.api.response.ActivatedJob;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class AcknowledgeInput {

    private final static Logger LOG = LoggerFactory.getLogger(AcknowledgeInput.class);
    @JobWorker(name = "acknowledgeInput")
    public void acknowledgeInput(final ActivatedJob job){
        LOG.info("AcknowledgeInput job triggered");
    }
}