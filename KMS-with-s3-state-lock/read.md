terraform -version        # must be 1.10 or newer
aws sts get-caller-identity
aws configure get region  # ap-southeast-2 is fine
aws s3 ls                 # see what already exists