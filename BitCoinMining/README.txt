DOS(COP 5615) PROJECT 1:

TEAM MEMBERS:
Name: Poornima Kumar
UFID: 5684-4925
Email ID: pkumar07@ufl.edu

Name: Harika Bukkapatnam
UFID: 3683-6895
Email ID: harikabukkap@ufl.edu

Running the project:
Download the compressed file on both server and client nodes and unzip it. Please make sure to run the server program before executing the client.

Steps to start Server:
To start the server, the following steps have to be executed in order:
1)Compilation: 
mix escript.build
2)Execution: 
./project1 k where k is the value of leading zeros
Example:
./project1 4

Steps to start Client:
On a different node, execute the following commands:
1)Compilation: 
mix escript.build
2)Execution: 
./project1 IP_address where IP_address is the Server IP address
Example:
./project1 192.168.43.161

Implementation Model Description:
Server Module:
i) master process: It is responsible for spawning multiple worker processes based on available logical processors available to the system.
ii) worker process: It Is responsible for mining coins by taking two parameters i.e number of zeros and work_unit_size and each of which starts with a unique random alpha numeric string concatenated with gator id and a nonce value starting from zero that is incremented by 1 in every iteration to find valid bit coins and returns a list of mined bitcoins as part of every request.
iii) printer process: It is responsible for displaying the mined coins reported by the server workers as well as the client workers.
iv) client_work_assigner process: It is responsible for receiving request for work parameters from client and send the parameters number of zeros and work_unit_size to the client.  

Client Module:
i) master process: It is responsible for spawning multiple worker processes based on available logical processors available to the system.
ii) worker process: It Is responsible for mining coins by taking two parameters i.e number of zeros and work_unit_size and each of which starts with a unique random alpha numeric string concatenated with gator id and a nonce value starting from zero that is incremented by 1 in every iteration to find valid bit coins and returns a list of mined bitcoins as part of every request.
iii) receive_work process: It is responsible for receiving the mined coins list from client's worker process.
iv) report_work process: It is responsible for reporting the received client worker mined coins list to the server.
v) get_work processes: It is responsible for requesting work parameters from server and after receiving work it sends them to client's workers for mining bitcoins.

Implementation Results:

1. Each of our worker processes receives two parameters i.e. the number of zeros k and the work_unit_size which is the number of bitcoins they mine in a single request from the master process. We tested our implementation for work_unit_size 100000, 50000 and achieved good results.

2. The result of running our program for the command time ./project 4 is as follows:
a) We could mine with work unit size per worker as 10 with the following statistics on 8 core processor:
(i) Real: 1m15.586s
(ii) User: 8m12.880s
(iii) Sys: 0m2.512s
(iv) CPU Utilization: 6.56

b) We could mine with work unit size per worker as 10 with the following statistics on 4 core processor: 
(i) Real: 6m6.828s
(ii) User: 23m0.709s
(iii) Sys: 0m21.27s
(iv) CPU Utilization: 3.82


3. The result of running our program for the command time ./project is 5 as follows:
a) We could mine with work unit size per worker as 10 with the following statistics on 4 core processor: 
(i) Real: 5m28.049s
(ii) User: 19m56.333s
(iii) Sys: 0m18.074s
(iv) CPU Utilization: 3.7

b) We could mine with work unit size per worker as 10 with the following statistics on 8 core processor: 
(i) Real: 1m18.179s
(ii) User: 8m39.480s
(iii) Sys: 0m1.108s
(iv) CPU Utilization: 6.67

4. The bitcoin with most 0s we managed to find is 8 on an 8 core machine.

5. The largest number of working machines(on 4 core and 8 core) we could run our code which is 5. 

Notes:
1. For the project to run successfully, ensure that the project file is present on both the server and the client.
2. The application appends "project@" to the IP address of the server and then makes the connection using project@IP_address
3. We have made used of :inet.getif() command in the client code to fetch the IP address of the client and the server.
4. On Windows PC, the command outputs ":undefined" for the gateway, which is unhandled in the project.
5. On Linux machine, we have assumed that the command will return two tuples, and we have made use of the first tuple {IP, gateway, subnet} to get the IP address of the client to make the connection.


