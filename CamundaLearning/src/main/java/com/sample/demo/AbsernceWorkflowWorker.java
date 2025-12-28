package com.sample.demo;

import io.camunda.client.annotation.JobWorker;
import io.camunda.client.annotation.Variable;
import io.camunda.client.api.response.ActivatedJob;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
public class AbsernceWorkflowWorker {

    private final static Logger LOG = LoggerFactory.getLogger(AbsernceWorkflowWorker.class);
    @JobWorker(name = "approveOrRejectAbsence")
    public Map<String,Object> approveOrRejectAbsence(final ActivatedJob job, @Variable boolean isApproved){
        LOG.info("Processing AbsernceWorkflowWorker with Job Key {}",job.getKey());
        Map<String,Object> map=job.getVariablesAsMap();
        map.put("isApproved",!isApproved);
        return map;
    }
}
