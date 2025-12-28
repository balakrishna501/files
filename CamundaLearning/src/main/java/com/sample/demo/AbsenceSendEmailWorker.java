package com.sample.demo;

import io.camunda.client.annotation.JobWorker;
import io.camunda.client.annotation.Variable;
import io.camunda.client.api.response.ActivatedJob;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
public class AbsenceSendEmailWorker {
    private final static Logger LOG = LoggerFactory.getLogger(AbsenceSendEmailWorker.class);
    @JobWorker(name = "sendEmail",autoComplete = true)
    public Map<String,Object> sendEmail(final ActivatedJob job, @Variable boolean isApproved){
        if (isApproved){
            LOG.info("Your Absence is approved....");
            LOG.info("Sending Approved email notification");
        }else {
            LOG.info("Your Absence is Rejected....");
            LOG.info("Sending Rejection email notification");
        }

        return job.getVariablesAsMap();
    }
}
