# jdoodletest
**The assumptions for the terraform script are
1) Used the local aws cli sdk for the AWS authentication
2) The versions I have used are
   a) terraform : 1.17
   b) Python : 3.8



Things to be updated before executing the script
1) Profile for script execution at provider section in Main.tf. If not need update it accordingly.(at line 2)
2) Security group for the launch template in main.tf.(at line 33)
3) Region in vars.tf.(at line 2)
4) VPC in vars.tf. ( at line 6)
5) subnets in vars.tf. (at lines 10, 14, 18)
