/*
Letting Snowflake & OpenAI Talk to Each Other

When you signed up for OpenAI, you came up with a name and password that you wanted to use to log in. Acting as yourself, you logged in and interacted with their models using a Web User Interface (WebUI).

OpenAI figures you might want to interact with their models in other ways. For example, you might want to allow your Snowflake account to sign in and interact with your OpenAI account.

So how can you do this? You'll need to do a little work on the Snowflake side of things, and a little work on the OpenAI side of things.

🔓  Allow Other Roles to Use the COMPUTE_WH Warehouse

Start a new worksheet or notebook in Snowflake, and grant warehouse usage permissions to SYSADMIN and PUBLIC roles.

*/


/*
SYSADMIN and PUBLIC roles will need to use the
warehouse at some point in this module
*/

use role ACCOUNTADMIN;
grant usage on warehouse COMPUTE_WH to role SYSADMIN;
grant usage on warehouse COMPUTE_WH to role PUBLIC;


/*
we are calling our database SF_LLM, but you can call yours whatever you want
*/

use role SYSADMIN;
create database SF_LLM;

*/
because SYSADMIN owns the database, both SYSADMIN and ACCOUNTADMIN
can do almost anything they need to do. Later in this module, we will
want PUBLIC to be able to run SELECT statements, so we should grant
access for PUBLIC 
*/

/*
SYSADMIN and PUBLIC roles will need to use the
warehouse at some point in this module
*/

use role ACCOUNTADMIN;
grant usage on warehouse COMPUTE_WH to role SYSADMIN;
grant usage on warehouse COMPUTE_WH to role PUBLIC;


grant usage on database SF_LLM to role PUBLIC;
grant usage on schema SF_LLM.PUBLIC to role PUBLIC;



-- tell Snowflake it is okay to reach out to the URL api.openai.com

use role SYSADMIN;
create or replace NETWORK RULE openai_network_access
mode = egress
type = host_port
value_list = ('api.openai.com');


/*

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

*/

-- Tell Snowflake What Password to Use

Now make sure your project has your API Key so you can use it in the project:
-- tell Snowflake what key/password to use when it reaches out

create or replace SECRET openai_secret
    type = generic_string
    secret_string = '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';



NOTE: If you are using a Snowflake Trial Account for this module, you MUST enter a billing credit card or you will not be able to complete this step.  This does not mean you will be charged. As long as you have Resource Monitors in place, and you control the usage of your trial account credits, you can easily avoid getting billed. However, it is YOUR RESPONSIBILITY, not ours, to make sure you do not get charged. 



    --join the URL info and the key info into one object

use role ACCOUNTADMIN;
create or replace EXTERNAL ACCESS INTEGRATION openai_access_integration
 allowed_network_rules = (openai_network_access)
 allowed_authentication_secrets = (openai_secret)
 enabled = true;


 /*
A Function for Sending Requests from Snowflake to Open AI

Before presenting you with a function that can send your requests to OpenAI, we want you to spend some time really LOOKING at the function. If you have experience with functions, this should be a quick exercise. If you are new to functions, this exercise should make functions seem less mysterious.

Remember that functions:

    Get information passed in called parameters

    Can send information back out or "return" information

When you define the information going in or coming back out, you also have to state a data type. Will you be sending in numbers? or words? Will you be getting back TRUE/FALSE? or a table of values?

Look at the function header (we don't show you the code block yet) in the image below and answer some questions about the inputs and outputs.  It's okay to infer and/or guess the answers. 

 */

 create or replace call_chartgpt(prompt STRING)
 return string
 language python
 runtime_version = 3.10
 handler = 'promp_chatGPT'
 external_access_integration = (open_ai_integration)
 packages = ('requests', 'openai')
 SECRETS = ('cred' = chatgpt_api_key)
 as
 $$
 import _snowflake
 import openai 
 import requests

 /*
1. Why It Looks Like SQL But Contains Python

The code you are looking at is a Snowflake DDL (Data Definition Language) statement acting as an outer container or shell. Everything from the CREATE command down to the opening dollar-quote delimiter ($$) is standard Snowflake SQL syntax used to configure metadata, runtime versions, security integrations, and package dependencies for a database object.

However, once Snowflake reaches the AS $$ block, the language switches entirely. Everything enclosed within those dollar-quoted delimiters is pure Python code executed natively inside Snowflake's secure container sandbox. In short, you are writing a SQL command that tells Snowflake how to build and configure a Python program on its server.
2. Where We Enable and Use the Packages

Making external Python packages available and usable requires two distinct steps across different lines in your snippet:

    Line 7 (packages = ('requests', 'openai')): This is where you instruct Snowflake's cloud environment to provision and install those specific libraries into the container runtime before execution.

    Lines 12 and 13 (import openai, import requests): These are the exact lines within the Python script body where you actually import those provisioned libraries into your code's local namespace, making their classes and methods available for your script logic to call.
 */

/*
On what line number(s) do we actually make it possible to use the "installed" Python packages in our code? ====> Answer = Line 7,11,12,and 13
 */


/* Using the OpenAI API from a Snowflake function

Copy the code below, paste it into a Snowflake Worksheet and replace the <bracketed text> will the right values. You will need to figure out what those correct values are. The Python libraries you need are requests and openai

*/

use role ACCOUNTADMIN;

grant usage on FUNCTION ask_mon_ami(string) to SYSADMIN;


# -- Create a snowflake function for the prompt

CREATE OR REPLACE FUNCTION SF_LLM.PUBLIC.GEN_HAIKU(PROMPT VARCHAR)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
ARTIFACT_REPOSITORY = snowflake.snowpark.pypi_shared_repository
PACKAGES = ('openai==1.0.0')
HANDLER = 'prompt_gen_haiku'
EXTERNAL_ACCESS_INTEGRATIONS = (OPENAI_ACCESS_INTEGRATION)
SECRETS = ('cred' = OPENAI_SECRET)
AS $$
import _snowflake
from openai import OpenAI

client = OpenAI(api_key=_snowflake.get_generic_secret_string('cred'))

def prompt_gen_haiku(prompt):
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": "When I give you a topic, you will write a haiku about that topic."},
            {"role": "user", "content": prompt},
        ],
    )
    return response.choices[0].message.content
$$

# Check package version for openai
select * from information_schema.packages
where package_name = 'openai'
and Language = 'python'
and runtime_version = 3.10;

select ask_mon_ami('what is the best soda flavor?');



grant usage on FUNCTION ask_mon_ami(string) to SYSADMIN;


-- Another version of the above code

select ask_mon_ami('which is better croisants or bagels');

Create a Function that will Write Haikus

Copy and paste the ask_mon_ami function then make the changes necessary to the code to create a second function.

    You'll have to use the ACCOUNTADMIN role when creating the function.

    After creating it, be sure to GRANT USAGE on the function to SYSADMIN.

    We will name our function and handler gen_haiku.  

    We will be replacing the prompt variable with a variable name of topic.



CREATE OR REPLACE FUNCTION SF_LLM.PUBLIC.GEN_HAIKU(PROMPT VARCHAR)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
ARTIFACT_REPOSITORY = snowflake.snowpark.pypi_shared_repository
PACKAGES = ('openai==1.0.0')
HANDLER = 'prompt_gen_haiku'
EXTERNAL_ACCESS_INTEGRATIONS = (OPENAI_ACCESS_INTEGRATION)
SECRETS = ('cred' = OPENAI_SECRET)
AS $$
import _snowflake
from openai import OpenAI

client = OpenAI(api_key=_snowflake.get_generic_secret_string('cred'))

def prompt_gen_haiku(prompt):
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": "When I give you a topic, you will write a haiku about that topic."},
            {"role": "user", "content": prompt},
        ],
    )
    return response.choices[0].message.content
$$;

grant usage on FUNCTION ask_mon_ami(string) to SYSADMIN;

use role sysadmin;

select gen_haiku('balloons');



SELECT CURRENT_ROLE(), CURRENT_DATABASE(), CURRENT_SCHEMA();
SHOW FUNCTIONS LIKE 'GEN_HAIKU%';


# Check package version for openai
select * from information_schema.packages
where package_name = 'openai'
and Language = 'python'
and runtime_version = 3.10;



What I changed and deployed:

    ChatCompletion error: fixed by switching to the 1.x client API (OpenAI(...) and client.chat.completions.create(...)).
    Second error: once that was fixed, the test hit TypeError: Client.__init__() got an unexpected keyword argument 'proxies'. openai==1.0.0 doesn't work with newer versions of its httpx dependency, so I pinned httpx==0.27.2 in PACKAGES.
    Model and response: the model is now gpt-4o, and the result is read with message.content.

The last test got as far as OpenAI, so the secret, the network access setup (OPENAI_ACCESS_INTEGRATION) and the package setup all worked. No haiku has come back yet, though, so the response-reading line hasn't actually run.

Next step: add credits at https://platform.openai.com/settings/organization/billing/ or put a key from another account into OPENAI_SECRET. Then run SELECT SF_LLM.PUBLIC.GEN_HAIKU('autumn'); again.

If you'd rather not depend on OpenAI billing, I can rewrite the function to use Snowflake's built-in AI_COMPLETE. That needs no API key or network access setup.


CREATE OR REPLACE FUNCTION SF_LLM.PUBLIC.GEN_HAIKU(PROMPT VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
  AI_COMPLETE(
    'llama3.1-70b',
    'When I give you a topic, you will write a haiku about that topic. Respond with only the haiku.\n\nTopic: ' || PROMPT
  )::VARCHAR
$$;







I rewrote SF_LLM.PUBLIC.GEN_HAIKU to use Snowflake's built-in AI_COMPLETE, and the test now works. 

SELECT SF_LLM.PUBLIC.GEN_HAIKU('autumn'); returned:

    Golden leaves descend Crisp air whispers through the trees Nature's color dance

The new function is plain SQL, so it doesn't need Python packages, the OpenAI secret, network access setup, or an OpenAI account:
sql

CREATE OR REPLACE FUNCTION SF_LLM.PUBLIC.GEN_HAIKU(PROMPT VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
  AI_COMPLETE(
    'llama3.1-70b',
    'When I give you a topic, you will write a haiku about that topic. Respond with only the haiku.\n\nTopic: ' || PROMPT
  )::VARCHAR
$$;

    Model: I first tried claude-4-sonnet, but it isn't available in this account's region, so the function uses llama3.1-70b. To use a different model, change the first argument.
    Return type: AI_COMPLETE returns VARIANT here, so the result is cast to ::VARCHAR to keep the original return type.
    Billing: the function now uses Snowflake credits instead of OpenAI billing.

The Python version has been replaced. Nothing uses OPENAI_SECRET or OPENAI_ACCESS_INTEGRATION any more. I left both in place, and you can drop them if nothing else needs them.




This is the new code that uses llama instead of ChatGPT


CREATE OR REPLACE FUNCTION SF_LLM.PUBLIC.GEN_HAIKU(PROMPT VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
  AI_COMPLETE(
    'llama3.1-70b',
    'When I give you a topic, you will write a haiku about that topic. Respond with only the haiku.\n\nTopic: ' || PROMPT
  )::VARCHAR
$$;



We want to create a table to store history of haiku topics searched.

use role sysadmin;

CREATE OR Replace TABLE SF_LLM.PUBLIC.generated_haikus (
    topic STRING,
    haiku STRING,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);