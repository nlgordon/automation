import groovy.json.JsonSlurper


JsonSlurper slurper = new JsonSlurper()
def auth = slurper.parseText(new File("/opt/auth/api.cloudfoundry.com.auth").text)

def login = "vmc login --username ${auth.user} --password ${auth.password}"

println "Logging in"

def loginProcess = login.execute()

loginProcess.waitFor()

if (loginProcess.exitValue()) {
	print loginProcess.err.text
	exit
}

def serviceCommand = "vmc services --service mysql -q"

println "Getting services"

def serviceProcess = serviceCommand.execute()

serviceProcess.waitFor()

if (serviceProcess.exitValue()) {
	print serviceProcess.err.text
}

def services = []

def serviceLines = serviceProcess.text.eachLine({
	def matches = it =~ /([^ ]*) .*/
	services << matches[0][1]
})

println services

String curDate = new Date().format("yyyy-MM-dd");

File dayDir = new File("/var/backups/api.cloudfoundry.com/${curDate}/")

if (!dayDir.exists()) {
	println "Making dir ${dayDir}"
	if (!dayDir.mkdir()) {
		println "Unable to create backup dir"
		System.exit(1)
	}
}

services.each {
	println "Backing up ${it}"
	
	def ant = new AntBuilder()   // create an antbuilder
	ant.exec(outputproperty:"cmdOut",
	errorproperty: "cmdErr",
	resultproperty:"cmdExit",
	failonerror: "true",
	executable: 'vmc') {
		arg(line:"tunnel ${it} mysqldump -q")
	}
	println "return code:  ${ant.project.properties.cmdExit}"
	println "stderr:         ${ant.project.properties.cmdErr}"
	println "stdout:        ${ ant.project.properties.cmdOut}"
	System.exit(0)
	
	
	
	
	
	
	def backupCommand = "tunnel ${it} mysqldump -q"
	println "Running ${backupCommand}"
	Process backupProcess = backupCommand.execute()
	
	def output = new StringBuffer()
	def error = new StringBuffer()
	
	backupProcess.consumeProcessOutput(output, error)
	print output
	print error
	backupProcess.out << "${dayDir}backup-${it}.sql"
	backupProcess.consumeProcessOutput(output, error)
	print output
	print error
	backupProcess.waitFor()

	if (backupProcess.exitValue()) {
		print backupProcess.err.text
	}
	
	print backupProcess.text
}
