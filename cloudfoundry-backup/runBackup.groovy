import groovy.json.JsonSlurper


JsonSlurper slurper = new JsonSlurper();
slurper.parseText(new File("/opt/auth/api.cloudfoundry.com.auth").text)