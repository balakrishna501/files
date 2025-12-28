package com.sample.demo;

import io.camunda.client.annotation.JobWorker;
import io.camunda.client.api.response.ActivatedJob;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
public class ProcessAbasencesWorker {

    private final static Logger LOG = LoggerFactory.getLogger(ProcessAbasencesWorker.class);

    @JobWorker(name = "processAbsences")
    public Map<String, Object> processAbsences(final ActivatedJob job){
        LOG.info("Processing Absences with key {}",job.getKey());
        LOG.info("Creating Approval Approval process to manager");
        Map<String,Object> processVariables=job.getVariablesAsMap();
        processVariables.put("isApproved",false);
        return processVariables;
    }
}
