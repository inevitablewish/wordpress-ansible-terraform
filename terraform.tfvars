database_name           = "wordpress_db"          // database name
database_user           = "wordpress_user"        //database username
shared_credentials_file = "~/.aws"                //Access key and Secret key file location
region                  = "ap-southeast-2"        //sydney region
PUBLIC_KEY_PATH         = "./wp-key.pub"          // key name for ec2, make sure it is created before terrafomr apply
PRIV_KEY_PATH           = "./wp-key"
instance_type           = "t2.micro"              //type of instance
instance_class          = "db.t2.micro"
