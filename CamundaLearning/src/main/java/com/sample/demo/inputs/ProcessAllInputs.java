package com.sample.demo.inputs;

import com.sample.demo.SendEscalation;
import io.camunda.client.annotation.JobWorker;
import io.camunda.client.api.response.ActivatedJob;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class ProcessAllInputs {

    private final static Logger LOG = LoggerFactory.getLogger(ProcessAllInputs.class);
    @JobWorker(name = "processAllInputs")
    public void processAllInputs(final ActivatedJob job){
        LOG.info("Processed All Inputs");
    }
}
