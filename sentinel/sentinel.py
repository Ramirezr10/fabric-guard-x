import time   # Time access and conversions.
import subprocess # Subprocess management
from prometheus_client import start_http_server, Gauge 
# http start a lightweight deamon within this process 
# Gauge is for measuring values that can fluctuate


#Defining our Promethues Metrics
FABRIC_DROPS = Gauge('fabricguard_network_drop_total', 'Total dropped packets', ['interface'])


def get_status(interface):
	"""Parse /proc/net/dev to fine th stats for a specific interface."""
	with open("/proc/net/dev", "r") as f:
		lines = f.readlines() #"lines" will be each line parse within /proc/net/dev 
		for line in lines: 		#for loop for lines and set the rule for the loop below
			if interface in line:
				data = line.split()  #data = the line read +split the whitespaces
				# Index 4 is Receive Drops, Index 12 is Transmit Drops in /proc/net/dev
				drops = int(data[4]) + int(data[12])
				errs = int(data[3]) + int(data[11])
				return drops, errs # ends the if statment and returns the logs within those index positions

	return 0, 0 # If cannot find anything return a 0 errs and 0 drops

if __name__ == '__main__':  # built-in variable within python if this file is the "main" script
	#start Prometheus exporter on port 8000
	start_http_server(8000, addr='0.0.0.0')
	print("Sentinel Agent v6 (Stress Test Mode) active...")

	while True:
		simulated_drops = 125.0
		#target 'net1' because that is what Multus named our fabric interface
		drops, errs = get_status("net1")

		FABRIC_DROPS.labels(interface="net1").set(simulated_drops)
		print(f"Reporting simulated drops: {simulated_drops}")

		time.sleep(5)
		#Will wait 5 second before running again