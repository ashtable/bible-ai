
Please execute the following steps:
1. Spawn a new general purpose agent to review the design.md and identify the next numbered task that has not been completed
2. Spawn a new general purpose agent to review the code in the current repo as well as the most recent commits
3. Spawn a tech-lead agent to review the context from Steps 1 and 2, and then create a test-driven development plan
4. Spawn a general purpose agent to explain the changes which need to be made, the end to end and/or unit tests that will be written, and then ask for permission to proceed or any desired changes to the proposed tdd plan.
5. Spawn a new tech-lead agent to implement each of the new or updated end to end and/or unit tests, and verify that the new tests fail as expected.
6. Spawn a general purpose agent to commit/push the changes, explain the end to end and/or unit tests that were written, which tests are now failing, and the code/config that needs to be written to make the failing tests pass, and request the user's permission to proceed.
7. Spawn a tech-lead agent agent to /loop until the tests pass
8. Spawn a general purpose agent to commit/push the changes, explain the code/config written to make the failing tests from Step 5 pass, which failing tests from Step 5 are now passing, and ask the user whether to proceed with the final code review or if any changes need to be made first. If more changes need to be made, repeat Steps 3 through 8 for any changes requested by the user.
9. Spawn a tech-lead agent to review the tdd plan from Step 3 and the code, config and tests written in Steps 4 through 8. Then ask this tech-lead agent to suggest any recommended revisions to the tests, code or config written in Steps 4 through 8.
10. Spawn a general purpose agent to review the tdd plan from Step 3, the code config and tests written in Steps 4 through 8, and the recommended revisions from Step 9. Then ask this general purpose agent to determine which of the recommended revisions from Step 9 are valid.
11. Spawn a general purpose agent to review the tdd plan from Step 3, the code config and tests written in Steps 4 through 8, and the recommended revisions from Step 9 that were deemed valid in Step 10. Then ask this general purpose agent to determine which of the recommended revisions deemed valid in Step 10 are necessary.
12. Spawn a general purpose agent to explain the recommended revisions from Step 9 that were deemed both valid and necessary in Steps 10 and 11, respectively, and then request permission from the user to proceed.
13. Spawn a new tech-lead agent to implement each of the new or updated end to end and/or unit tests, and verify that the new tests fail as expected.
14. Spawn a general purpose agent to commit/push the changes, explain new or updated end to end and/or unit tests that were written, which tests are now failing, and the code/config that needs to be written to make the failing tests pass, and request the user's permission to proceed.
15. Spawn a tech-lead agent agent to /loop until the tests pass
16. Spawn a general purpose agent to commit/push the changes, explain the code/config written to make the failing tests from Step 13 pass, which failing tests from Step 13 are now passing. 
17. Spawn a general purpose agent to update ./design.md by adding the suffix ` - Done!` to the number column of the task in that was just completed. Commit and push the change to ./design.md
