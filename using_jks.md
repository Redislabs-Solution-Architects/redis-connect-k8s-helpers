# Using a Java Truststore file with Redis Connect in K8s

You will need either `oc` or `kubectl` and the java keytool binary.

1. Create the trust store from a given cert, for example, the proxy cert on a RES cluster.
   This keystore formatted file contains `cert.pem` and has a password of `changeit`
```
➜  tech_exercise_terraform git:(master) ✗ keytool -import -alias example -file /etc/ssl/cert.pem -keystore truststore.jks -storepass changeit
Owner: CN=Autoridad de Certificacion Firmaprofesional CIF A62634068, C=ES
Issuer: CN=Autoridad de Certificacion Firmaprofesional CIF A62634068, C=ES
Serial number: 53ec3beefbb2485f
Valid from: Wed May 20 04:38:15 EDT 2009 until: Tue Dec 31 03:38:15 EST 2030
Certificate fingerprints:
...
Trust this certificate? [no]:  yes
Certificate was added to keystore
➜  tech_exercise_terraform git:(master) ✗ keytool -list -keystore truststore.jks
Enter keystore password:  
Keystore type: PKCS12
Keystore provider: SUN

Your keystore contains 1 entry

example, Feb 22, 2022, trustedCertEntry, 
Certificate fingerprint (SHA-256): 04:04:80:2<snip>3B:14:30:3F:90:14:7F:5D:40:EF
➜  tech_exercise_terraform git:(master) ✗ 
``` 

2. Upload and validate the secret in oc/kubectl. One secret is created with two keys: `truststore.jks` and `password.txt` containing the data from those two files in your filesystem.
```
➜  k8s-docs git:(main) ✗ oc create secret generic truststorezzz --from-file=truststore.jks --from-file=password.txt  
secret/truststorezzz created
➜  k8s-docs git:(main) ✗ oc get secret truststorezzz
NAME            TYPE     DATA   AGE
truststorezzz   Opaque   2      35s
➜  k8s-docs git:(main) ✗ oc describe secret/truststorezzz
Name:         truststorezzz
Namespace:    redis-1
Labels:       <none>
Annotations:  <none>

Type:  Opaque

Data
====
truststore.jks:  1858 bytes
password.txt:      8 bytes
                                                     
➜  k8s-docs git:(main) ✗ oc get secret truststorezzz -o jsonpath='{.data.password\.txt}' | base64 -d 
changeit
➜  k8s-docs git:(main) ✗
```

3. Example Redis Connect for Postgres in K8s stage manifest.
[This file](redis-connect-postgres-stage_jks_example.yaml) is a complete example manifest. Note that this example is for a Postgres source, but applies to all source DBs that Redis Connect supports. 
Look through the file for the `### TRUSTSTORE` braces.
* A password is required to read the truststore file. This is supplied to the redis connect pod using an environment variable using the k8s secret created above as source.
   ```
   env: 
   - name: TRUSTSTORE_PASSWORD
      valueFrom:
         secretKeyRef: 
         name: truststorezzz
         key: "password.txt" # might need to escape the `.`
   ```
* Create a mount point in the pod for the k8s secret:
   ```
   ### TRUSTSTORE change
        - name: truststore-volume
          mountPath: "/truststore"
          readOnly: true
   ### end TRUSTSTORE change
   ```
* Map the secret to the above mount point so that the truststore.jks file is available to the Redis Connect jvm.
   ```
   ### TRUSTSTORE
      - name: truststore-volume
        secret:
          secretName: truststorezzz
          items:
          - key: "truststore.jks" # this is the key in the k8s we store the file in
            path: "truststore.jks" # it will appear in the FS as /truststore/truststore.jks     
   ### end TRUSTSTORE change         
   ```
* Add the JVM options to leverage the trusstore file from the filesystem and password from the environment variables.
   ```
   ### end TRUSTSTORE change### TRUSTSTORE change
          - name: REDISCONNECT_JAVA_OPTIONS
            value: "-XX:+HeapDumpOnOutOfMemoryError -Xms256m -Xmx1g -Djavax.net.ssl.trustStore=/truststore/truststore.jks -Djavax.net.ssl.trustStorePassword=$(TRUSTSTORE_PASSWORD)"
   ### end TRUSTSTORE change
   ```
4. Proceed with your normal stage and start deployments for Redis Connect


### Resources

* https://developers.redhat.com/blog/2020/06/05/adding-keystores-and-truststores-to-microservices-in-red-hat-openshift#secure_and_deploy_a_rest_based_web_service
* https://medium.com/@vishwanath.leo/how-to-pass-your-custom-truststore-as-argument-to-jvm-when-running-a-jar-file-f9e05adc5094
