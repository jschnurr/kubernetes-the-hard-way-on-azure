# Cleaning up

Once you have completed practice or made irreparable misconfigurations at some place, you can always clean the slate to go back in time.

```
cd ~/kthw-azure-git/infra

# destroy the provisioned environment and everything along with it
../scripts/clean-slate.sh

# if you wish to delete the earlier generated certificate files as well then
../scripts/clean-slate.sh true
```