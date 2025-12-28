package com.sample.demo;

import io.camunda.client.annotation.JobWorker;
import io.camunda.client.annotation.Variable;
import io.camunda.client.api.response.ActivatedJob;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
public class SendEscalation {

    private final static Logger LOG = LoggerFactory.getLogger(SendEscalation.class);

    @JobWorker(name = "sendEscalation")
    public Map<String,Object> sendEscalation(final ActivatedJob activatedJob, @Variable String receivedInput){
        LOG.info("Input received with {}",receivedInput);
        Map<String,Object>  map = activatedJob.getVariablesAsMap();
      //  map.put("receivedCount",Integer.parseInt(receivedCount)+1);
        return map;
    }
}
