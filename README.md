# Acebook on AWS exemplar

This repository contains an exemplar for the [Acebook on AWS](https://gitlab.com/makers-students/devops-course/-/tree/main/acebook-on-aws) project.

It does not cover all aspects of the project as there is already a [walkthrough](https://gitlab.com/makers-students/devops-course/-/blob/main/acebook-on-aws/high-level-walthrough.md) available for the initial tasks of setting up the infrastructure.

This repository shows how to:
- fix the CI jobs provided in the project template so that they pass,
- add a CD job that deploys the app using CodeDeploy,
- write the configuration files necessary for CodeDeploy to correctly deploy the app.

It also provides:
- explanations on which IAM roles and permissions needed to be set up,
- answers to the prompts contained in the [template .gitlab-ci.yml file](https://gitlab.com/makers-students/acebook-node-template/-/blob/master/.gitlab-ci.yml) provided in the template project.

## CI-CD

This repo has working version of the `.gitlab-ci.yml` file provided in the initial project seed (in which some parts were missing or out of order).
In particular, the missing CD job that shows how to upload the application to S3 and then direct CodeDeploy to deploy it onto EC2 has been added.

There were also a couple of questions to think about in the `.gitlab-ci.yml` file.
Those are answered inline in the comments of the file.

## Setting up the EC2 instance

### Instance profile

The EC2 instance we create needs an [instance profile](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html).
An instance profile allows passing a [role](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html) to an EC2 instance.
We can attach policies to this role so that the EC2 instance is granted permission to perform certain actions (e.g. access other AWS services).

Our EC2 instance needs permission to read the contents of buckets in S3. 
There are two reasons for this:
- it needs access to the CodeDeploy bucket on S3 so that it can download the CodeDeploy agent from there
- it needs access to the S3 bucket we created so that the CodeDeploy agent (once running on the instance) can download the application bundle from there

For how to set up an instance profile that meets these criteria, [see the CodeDeploy guide](https://docs.aws.amazon.com/codedeploy/latest/userguide/getting-started-create-iam-instance-profile.html#getting-started-create-iam-instance-profile-console).

### Security group

The EC2 instance needs a security group that allows inbound access:

- via SSH from any IP address
- via TCP on port 3000 from any IP address

Why TCP? TCP is the underlying protocol that HTTP uses (HTTP is a more high-level protocol built on top of it).

Why on port 3000? Because [our application runs on port 3000 by default](https://gitlab.com/makers-students/acebook-node-template/-/blob/master/bin/www#L16). 

#### Node

Since our application is built using Node, Node needs to be installed on the EC2 instance in order for the deployment scripts described in the CodeDeploy sections to work.
For how to do this, see the [AWS tutorial](https://docs.aws.amazon.com/sdk-for-javascript/v2/developer-guide/setting-up-node-on-ec2-instance.html) on this topic.

#### Database

The Acebook project also relies on a MongoDB database to work.
The simplest way to get the database part working is to [install MongoDB on the EC2 instance](https://docs.mongodb.com/manual/tutorial/install-mongodb-on-amazon/) we deployed the app to.

> :warning: **Warning**
This is not a production-ready solution.
If our instance went down, we'd also lose all of our data.
In a real production environment, we'd have our database running on a separate server and keep backups to avoid this.



## CodeDeploy

### IAM

CodeDeploy needs permission to perform actions on our behalf.
We can grant CodeDeploy these permissions by creating a [service role](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_terms-and-concepts.html) in the IAM Console.
This service role needs to have the `AWSCodeDeployRole` policy attached.

The `AWSCodeDeployRole` policy allows CodeDeploy to identify the EC2 instance it should deploy the code to, among other things (for more details see the [CodeDeploy docs](https://docs.aws.amazon.com/codedeploy/latest/userguide/getting-started-create-service-role.html)).

For a walkthrough of how to do create such a role, see [this CodeDeploy guide](https://docs.aws.amazon.com/codedeploy/latest/userguide/getting-started-create-service-role.html#getting-started-create-service-role-console).

### Configuring deployments

CodeDeploy needs to be given instructions for what to do with the application files it to copies from S3 to EC2.
In particular, it needs to be told where to copy them to, how to install the dependencies needed to run the application and how to run the application.

To do so, we write an [AppSpec file](https://docs.aws.amazon.com/codedeploy/latest/userguide/application-specification-files.html) and include it in our application bundle.
Among other things, this file can be used to specify what CodeDeploy should do at different stages of the deployment process. 
CodeDeploy calls these stages *lifecycle events*.

We can tell CodeDeploy what to do for each of these events using so-called [event hooks](https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file-structure-hooks.html). 
CodeDeploy defines many events but not all of them are relevant to this project.

We mainly care about the following events:

- `ApplicatonStop` - This deployment lifecycle event occurs even before the application revision is downloaded. You can specify scripts for this event to gracefully stop the application or remove currently installed packages in preparation for a deployment. For this project, at a minimum, we need to stop any server that's potentially already running (because it was started by a previous deployment) before starting the server again with the new copy of our code. Otherwise, the process running our new server code would try to use the same port as the existing server that's already running, and it would fail to start. (If you're not quite sure what is meant by this, try to reproduce this problem locally by running `npm start` in two different terminal windows at the same time. Does it work?)
- `AfterInstall` – Used to run tasks after the application bundle has been copied to the instance. This is a good time to install dependencies because our `package.json` file, which specifies which dependencies are needed for our app, is now on the instance.
- `ApplicationStart` – You typically use this deployment lifecycle event to restart services that were stopped during `ApplicationStop`. In our case, we want to start our server using the new code in the application bundle that CodeDeploy just copied to the instance for us.

#### Defining what CodeDeploy should do for each event

In our `appspec.yml`, we can specify paths to Bash scripts that should be run for each of these events.
These Bash scripts are what CodeDeploy calls *event hooks*.
They need to be part of our application bundle. 

The scripts need to contain commands that achieve what we want, much like how we added commands to our CI/CD jobs to tell GitLab how to run our tests.
In this case, we need to come up with commands that when executed will:

- stop the server,
- install dependencies,
- start the server.

We need 3 scripts, one for each of the tasks above.
You can find the necessary scripts under the [scripts](scripts) directory in this repository.

During deployment, the CodeDeploy agent reads the `appspec.yml` in our application bundle and looks up whether it should run any hooks for the current event using the `hooks` section of the AppSpec file.
CodeDeploy will find follow the paths in the `hooks` section of the AppSpec file to find scripts in the application bundle and run them at the appropriate time.

You can find the `appspec.yml` file for this project [here](appspec.yml).

> :warning: **Warning**
Note that for CodeDeploy to find the AppSpec file, the AppSpec file needs to be in the root directory of the application bundle, i.e. in the root directory of your repository (also sometimes referred to as the [top-level directory](https://techstacker.com/what-does-top-level-folder-directory-mean/)).
CodeDeploy will fail to deploy the application if it can't find the AppSpec file at top-level of the ZIP file.







