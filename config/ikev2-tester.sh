#!/usr/bin/env bash

echo '
   /$$$$$$ /$$   /$$ /$$$$$$$$       /$$$$$$$$                    /$$                        
  |_  $$_/| $$  /$$/| $$_____/      |__  $$__/                   | $$                        
    | $$  | $$ /$$/ | $$               | $$  /$$$$$$   /$$$$$$$ /$$$$$$    /$$$$$$   /$$$$$$ 
    | $$  | $$$$$/  | $$$$$            | $$ /$$__  $$ /$$_____/|_  $$_/   /$$__  $$ /$$__  $$
    | $$  | $$  $$  | $$__/            | $$| $$$$$$$$|  $$$$$$   | $$    | $$$$$$$$| $$  \__/
    | $$  | $$\  $$ | $$               | $$| $$_____/ \____  $$  | $$ /$$| $$_____/| $$      
   /$$$$$$| $$ \  $$| $$$$$$$$         | $$|  $$$$$$$ /$$$$$$$/  |  $$$$/|  $$$$$$$| $$      
  |______/|__/  \__/|________/         |__/ \_______/|_______/    \___/   \_______/|__/      
'

while getopts ":n:s:i:" option; do
    case $option in
        n)
      	    attempts="$OPTARG"
      		;;
        s)
            suite="$OPTARG"
            if [ $suite == 1 ];
			then
                conn="base-mschap"
                enc_alg="AES 128 CBC"
                auth_alg="HMAC 256"
                prf_alg="AES 128 XCBC"
                dh_alg="ECP 256"
                auth_method="EAP MSCHAPv2"
            elif [ $suite == 2 ]
            then
                conn="base-rsa"
                enc_alg="AES 128 CBC"
                auth_alg="HMAC 256"
                prf_alg="AES 128 XCBC"
                dh_alg="ECP 256"
                auth_method="X.509 RSA 2048 Certificate"
            elif [ $suite == 3 ]
            then
                conn="base-ecdsa"
                enc_alg="AES 128 CBC"
                auth_alg="HMAC 256"
                prf_alg="AES 128 XCBC"
                dh_alg="ECP 256"
                auth_method="X.509 ECDSA 256 Certificate"
            else
                $(echo "Suite must be 1 or 2 ...")
                exit 1
            fi
            ;;
        i)
            interface="$OPTARG"
            $(sudo timeout --preserve-status 0.5 tcpdump -ni $interface > /dev/null 2>&1 || $(echo "Supplied interface doesn't exist!" && exit))
            ;;
        *)
            echo "Usage: $0 [-n number_of_attempts] [-s suite] [-i interface]"
            exit 1
            ;;
    esac
done

if [ -z $suite ] || [ -z $suite ] || [ -z $interface ]
then
    echo "Set all flags!"
    echo "Usage: $0 [-n number_of_attempts] [-s suite] [-i interface]"
    exit 1
fi

echo ""
echo "###############################################"
echo ""
echo "Number of attempts: $attempts"
echo ""
echo "###############################################"
echo ""
echo "Chosen suite: $suite"
echo " - Encryption algorithm: $enc_alg"
echo " - Authentication algorithm: $auth_alg"
echo " - Pseudo Random Function algorithm: $prf_alg"
echo " - Diffie-Hellman Group: $dh_alg"
echo " - Authentication Method: $auth_method"
echo ""
echo "###############################################"
echo ""

cumulative_time=0
sudo ipsec down $conn > /dev/null
sleep 3

for (( att=1; att<=$attempts; att++ ))
do
    echo "Starting attempt $att"
    sleep 1
    sudo timeout --preserve-status 3 tcpdump -tt -l -w inittmpbuffer1 -Z root port 500 >/dev/null 2>&1 &
    sudo timeout --preserve-status 3 tcpdump -tt -l -w authtmpbuffer1 -Z root port 4500 >/dev/null 2>&1 &
    sleep 1 && sudo ipsec up $conn > /dev/null
    sleep 3 && sudo ipsec down $conn > /dev/null
    sleep 5
    sudo tcpdump -tt -Z root -r inittmpbuffer1 > inittmpbuffer2 2>&1
    sudo tcpdump -tt -Z root -r authtmpbuffer1 > authtmpbuffer2 2>&1
    echo "tcpdump over!"
    init_packets=$(grep -Eo "^[0-9]+" inittmpbuffer2 | wc -l | grep -Eo "^[0-9]+")
    auth_packets=$(grep -Eo "^[0-9]+" authtmpbuffer2 | wc -l | grep -Eo "^[0-9]+")
    init_start_time=$(grep -Eo "^[0-9]+.[0-9]+" inittmpbuffer2 | head -n 1)
    init_end_time=$(grep -Eo "^[0-9]+.[0-9]+" inittmpbuffer2 | tail -n 1)
    auth_start_time=$(grep -Eo "^[0-9]+.[0-9]+" authtmpbuffer2 | head -n 1)
    auth_end_time=$(grep -Eo "^[0-9]+.[0-9]+" authtmpbuffer2 | tail -n 1)
    init_time=$(echo "scale=6; $init_end_time - $init_start_time" | bc)
    auth_time=$(echo "scale=6; $auth_end_time - $auth_start_time" | bc)
    attempt_time=$(echo "scale=6; $auth_end_time - $init_start_time" | bc)
    attempt_packets=$(( init_packets + auth_packets ))
    cumulative_time=$(echo "scale=6; $cumulative_time + $attempt_time" | bc)
    echo " ----------------------------"
    echo "| Init time     | 0$init_time   |"
    echo " ----------------------------"
    echo "| Init packets  | $init_packets          |"
    echo " ----------------------------"
    echo "| Auth time     | 0$auth_time   |"
    echo " ----------------------------"
    echo "| Auth_packets  | $auth_packets          |"
    echo " ----------------------------"
    echo "| Total time    | 0$attempt_time   |"
    echo " ----------------------------"
    echo "| Total packets | $attempt_packets          |"
    echo " ----------------------------"
    echo ""
    echo "###############################################"
    echo ""
    rm inittmpbuffer1 inittmpbuffer2 authtmpbuffer1 authtmpbuffer2
done

average_time=$(echo "scale=6; $cumulative_time / $attempts" | bc)

echo "All attempts executed!"
echo " -------------------------------------"
echo "| Average time per attempt | 0$average_time |"
echo " -------------------------------------"
echo "| Total attempts time      | 0$cumulative_time |"
echo " -------------------------------------"
echo ""
echo "Goodbye!"
echo ""
echo "###############################################"
echo ""
