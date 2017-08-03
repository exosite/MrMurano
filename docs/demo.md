

# Every sub-command will --help

# Start anew
- Clone project: `git clone https://github.com/tadpol/GWE-Multitool.git demo01`
- `cd demo01`

- Pick a business: `murano business list`
- Set it: `murano config business.id ZZZZZZZZZ`

- Create a product: `murano product create myawesomeproduct`
- Save the result: `murano config product.id YYYYYYYYY`

- Set the product definition: `murano config product.spec gwe-multitool.yaml`
- Set the directory to look for specs. `murano config location.specs spec`
- Sync the product definition up: `murano syncup -V --specs`

- Create an application: `murano application create myawesomesolution`
- Save the result: `murano config application.id XXXXXX`
- Assign the product to the application: `murano assign set`

# What got configured?
`murano config --dump`






# <voice type='orc'>Work Work</voice>

- What is going to change? `murano status`
- Sync solution code up: `murano syncup -V`

- Change a file
- What is going to change? `murano status`
- Details of change: `murano diff`




# Devices
- Add a real device: `murano product device enable 42:42:42:42:42:42`
- !!!cheat and activate by hand: `murano product device activate 42:42:42:42:42:42`
- Which resources are there? `murano pull --resources && cat specs/resources.yaml`
- What did the device write to that one resource?
  `murano product device read 42:42:42:42:42:42 update_interval`
- `murano product device write 42:42:42:42:42:42 update_interval 300`



# Multiple configs
Because Developing, Staging, Production.

Set addition config file to load with `MR_CONFIGFILE`

Also supports '.env'




# Device Content Area

See GWE.





# Debugging

## Logs
- `murano logs`
- `murano logs --follow`






## Keystore
### What is in the Keystore?
`murano keystore list`

### Write and Read a Key
- `murano keystore set test greebled`
- `murano keystore get test`

### Write to a Set
- `murano keystore command sadd myset greebled`
Or any other supported Redis command.

### Remove just the ones with 'socketmap'
`murano keystore list | grep socketmap | xargs -L1 murano keystore delete`




## TSDB

- `murano tsdb list metrics`
- `murano tsdb list tags`
- `murano tsdb query @sn=1 temp0`
- `murano tsdb query @sn=1 temp0 --limit=4`
- `murano tsdb query @sn=1 --limit=10 -c outformat=csv --epoch ms`



