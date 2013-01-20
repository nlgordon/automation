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

services.each { println it }

Date curDate = new Date().format("YYYY-MM-dd");

File dayDir = new File("/var/backups/api.cloudfoundry.com/${curDate}")

if (!dayDir.exists()) {
	dayDir.mkdir()
}

services.each {
	def backupCommand = "vmc tunnel ${it} mysqldump"
	def backupProcess = backupCommand.execute()
	backupProcess.out << "backup-${it}.sql"
	backupProces.waitFor()

	if (backupProcess.exitValue()) {
		print backupProcess.err.text
	}
}
