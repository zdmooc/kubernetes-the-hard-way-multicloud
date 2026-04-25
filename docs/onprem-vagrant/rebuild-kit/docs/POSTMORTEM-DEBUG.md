# Postmortem Debug

Erreurs rencontrées et fixes intégrés :

1. `kubectl: command not found`  
   Fix : installation de kubectl v1.32.0 sur jumpbox.

2. SCP demande un mot de passe  
   Fix : upload des clés Vagrant dans `/home/vagrant/.ssh/*.key`.

3. DNS `kubernetes.local` non résolu  
   Fix : `/etc/hosts` sur jumpbox et workers.

4. `exec: runc not found`  
   Fix : installation de runc v1.2.5 sur workers.

5. CoreDNS CrashLoopBackOff  
   Fix : CoreDNS forward vers `8.8.8.8 1.1.1.1`.

6. `kubectl exec` TLS  
   Fix : CSR kubelet serving approuvés + `kubelet-preferred-address-types=Hostname,...`.

7. `Forbidden user=kubernetes nodes/proxy`  
   Fix : `clusterrolebinding kube-apiserver-to-kubelet`.

8. `system:kube-proxy cannot watch services/nodes/endpointslices`  
   Fix : `clusterrolebinding system:kube-proxy`.

9. DNS timeout inter-workers  
   Fix : routes PodCIDR + iptables FORWARD ACCEPT.
