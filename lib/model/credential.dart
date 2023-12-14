class Credential {
  String type = "";
  String projectId = "";
  String privateKeyId = "";
  String privateKey = "";
  String clientEmail = "";
  String clientId = "";
  String? authUri = "https://accounts.google.com/o/oauth2/auth";
  String? tokenUri = "https://oauth2.googleapis.com/token";
  String? authProviderX509CertUrl = "https://www.googleapis.com/oauth2/v1/certs";
  String clientX509CertUrl = "";

  Credential({required this.type, required this.projectId, required this.privateKeyId, required this.privateKey, required this.clientEmail, required this.clientId,this.authUri, this.tokenUri, this.authProviderX509CertUrl, required this.clientX509CertUrl});

  Credential.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    projectId = json['project_id'];
    privateKeyId = json['private_key_id'];
    privateKey = json['private_key'];
    clientEmail = json['client_email'];
    clientId = json['client_id'];
    authUri = json['auth_uri'];
    tokenUri = json['token_uri'];
    authProviderX509CertUrl = json['auth_provider_x509_cert_url'];
    clientX509CertUrl = json['client_x509_cert_url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['type'] = type;
    data['project_id'] = projectId;
    data['private_key_id'] = privateKeyId;
    data['private_key'] = privateKey;
    data['client_email'] = clientEmail;
    data['client_id'] = clientId;
    data['auth_uri'] = authUri;
    data['token_uri'] = tokenUri;
    data['auth_provider_x509_cert_url'] = authProviderX509CertUrl;
    data['client_x509_cert_url'] = clientX509CertUrl;
    return data;
  }
}