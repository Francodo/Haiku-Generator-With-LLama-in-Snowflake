About This App: A haiku is a short Japanese poetic form, traditionally 5–7–5 syllables that captures a fleeting moment or vivid image in just three lines. Because the format is compact and expressive, it makes a great testbed for pairing a lightweight Streamlit interface with a Snowflake-backed LLM (gen_haiku) to turn any topic into a three-line snapshot on demand.

The Goal of this App: (1) Demonstrate how to genrate Haikus using Snowflake function that calls llama3.1-70b (LLM). (2) Create a table to store the search history, with buttons to DISPLAY OR HIDE the Haiku history table as an option.

Here are the steps:

    Create Database and Schema in Snowflake (as in SF_LLM.PUBLIC)

    Create a table in Snowflake (as in CREATE OR Replace TABLE SF_LLM.PUBLIC.generated_haikus ( topic STRING, haiku STRING, created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP() ); )

    Create a function to generate Haikus in snawflake sql (as in CREATE OR REPLACE FUNCTION SF_LLM.PUBLIC.GEN_HAIKU(PROMPT VARCHAR) RETURNS VARCHAR LANGUAGE SQL AS #$$ AI_COMPLETE( 'llama3.1-70b', 'When I give you a topic, you will write a haiku about that topic. Respond with only the haiku.

Topic: ' || PROMPT )::VARCHAR #$$; )

    Create Python code in Streamlit for the UI (as below).
