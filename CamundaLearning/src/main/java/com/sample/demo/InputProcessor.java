package com.sample.demo;

import io.camunda.client.annotation.JobWorker;
import io.camunda.client.annotation.Variable;
import io.camunda.client.api.response.ActivatedJob;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
public class InputProcessor {

    private final static Logger LOG = LoggerFactory.getLogger(InputProcessor.class);

    @JobWorker(name = "processInput")
    public Map<String,Object> processInput(final ActivatedJob activatedJob, @Variable String receivedInput ,@Variable String receivedCount){
        LOG.info("Input received with {}",receivedInput);
        Map<String,Object>  map = activatedJob.getVariablesAsMap();
        map.put("receivedCount",Integer.parseInt(receivedCount)+1);
        return map;
    }
}
