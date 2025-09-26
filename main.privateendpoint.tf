/*
	Azure Red Hat OpenShift does not expose Azure Private Link endpoints for the cluster
	resource. The legacy private endpoint stubs have been intentionally removed.
	To enable private connectivity use `api_server_profile.visibility = "Private"`
	and private ingress profiles instead.
*/
