# import os

# from lxml import etree
# from datetime import date


ns = {
    "mei": "http://www.music-encoding.org/ns/mei",
    "xml": "http://www.w3.org/XML/1998/namespace",
}


# def write_to_console(message: str):
#     # might get more complicated!
#     print(format_user_output(message))


# def write_to_github_summary(message: str):

#     with open(os.getenv("GITHUB_STEP_SUMMARY"), "a") as f:
#         f.write(message)


# def format_user_output(
#     message: str,
# ):  # to create string according to GH-Action standard
#     return (
#         "::group::Application Results\n"
#         "---START_USER_MESSAGE---\n"
#         f"{message}\n"
#         "---END_USER_MESSAGE---\n"
#         "::endgroup::\n"
#     )
