#!/usr/bin/env ruby
require 'optparse'
require 'ostruct'
require 'yaml'

require 'RbVmomi'

class Options
    @result = nil
    @help = nil
    def self.new
        @result,@help = OpenStruct.new,OptionParser.new
        @help.banner = "Usage: "+@help.program_name+" [options] commands"
        @help.on_head("-h", "--help", "Show this message") do
            puts @help
            exit 0
        end

        @help.separator ""
        @help.separator "Common options:"

        @result.configfile = File.join(File.dirname(__FILE__),"vcenter.config")
        @help.on("-c path", "--config=path", "select configuration file (" << @result.configfile << ")") do |c|
            @result.configfile = c
        end

        @result.listdatacenter = false
        @help.on("-d", "list available data-centers") do
            @result.listdatacenter = true
        end

        @result.datacenter = nil
        @help.on("-D name", "--data-center=name", String, "select a specific data-center") do |d|
            @result.datacenter = d
        end

        @result.listresource = false
        @help.on("-r", "list available computer-resources") do
            @result.listresource = true
        end
        @result.resource = nil
        @help.on("-R name", "--compute-resource=name", String, "select a specific compute-resource") do |r|
            @result.resource = r
        end

        @result.listpath = false
        @help.on("-p", "list entities in the specified path") do
            @result.listpath = true
        end
        @result.path = ""
        @help.on("-P name", "--path=/path/to/vm", String, "select the path to the virtual machines") do |p|
            @result.path = p
        end

        @help.separator ""
        @help.separator "Commands:"
        @help.separator "\tfilter glob -- specifies a filter to select multiple vms. property=value"
        @help.separator "\tselect glob -- chooses a single vm"
        @help.separator "\tget field -- returns the specified property of a vm"
        @help.separator "\tlist [fields] -- lists any properties of a vm"
        @help.separator "\tpower [on,off,suspend,reset] -- flips the physical state of a vm"
        @help.separator "\tcycle [reboot,standby,shutdown] -- cycles a vm machine using vmware tools"
        @help.separator "\tsnapshot -- creates a snapshot"
        @help.separator "\tconsole -- allocates a console, outputs the URI to connect to it"
        @help.separator "\trename name -- renames a vm to the specified name"
        @help.separator "\tdestroy ref -- deletes the vm identified by the refid"
#        @help.separator "\tclone path -- clones the selected vm to a new path"

        @help.separator ""
        @help.separator "Properties:"
        @help.separator "\t" << ["storage", "Storage property"].join(" -- ")
        @help.separator "\t" << ["resourcePool", "Resource pool"].join(" -- ")
        @help.separator "\t" << ["summary", "VM summary"].join(" -- ")
        @help.separator "\t" << ["datastore", "Datastore location"].join(" -- ")
        @help.separator "\t" << ["network", "Network identifier"].join(" -- ")
        @help.separator "\t" << ["rootSnapshot", "Root snapshot image"].join(" -- ")
        @help.separator "\t" << ["guestHeartbeatStatus", "Guest status"].join(" -- ")
        @help.separator "\t" << ["macs", "Ethernet Addresses"].join(" -- ")
        @help.separator "\t" << ["disks", "Disk Identifiers"].join(" -- ")
        @help.separator "\t" << ["guest_ip", "Guest IPv4"].join(" -- ")
        @help.separator "\t" << ["configStatus", "Configuraiton status"].join(" -- ")
        @help.separator "\t" << ["name", "VM name"].join(" -- ")
        return self
    end

    def self.parse(args)
        if !(args.is_a? Array) || args.length == 0
            STDERR.puts @help
            exit 1
        end

        @help.order!(args)

        if args.length < 1
            STDERR.puts @help
            exit 1
        end
        @result.command = args

        self.check(@result) or exit 1
        return self.to_symbol(@result)
    end

    def self.check(result)
        if !File.exists?(result.configfile)
            STDERR.puts "Unable to open configuration " << result.configfile << "\n"
            return false
        end
        return true
    end

    def self.to_symbol(result)
        {
            :config => YAML.load_file(@result.configfile).map{|k,v| [k.to_sym,v]}.to_h,
            :command => @result.command,
            :listdatacenter => @result.listdatacenter,
            :datacenter => @result.datacenter,
            :listresource => @result.listresource,
            :resource => @result.resource,
            :listpath => @result.listpath,
            :path => @result.path,
        }
    end
end

class VmHelper
    def self.getSpec(vm)
        location = RbVmomi::VIM.VirtualMachineRelocateSpec
        #location[:datastore] = datastore unless datastore.nil?
        #location[:pool] = get_resource_pool(dc, machine) unless machine.provider_config.clone_from_vm

        spec = RbVmomi::VIM.VirtualMachineCloneSpec location: location, powerOn: false, template: false
        spec[:config] = RbVmomi::VIM.VirtualMachineConfigSpec
        return spec
    end

    def self.resolve(res, attributes)
        while (res.is_a? RbVmomi::BasicTypes::Base) && attributes.length > 0
            n = attributes.shift
            break if n.length == 0
            case n
                when /^([a-z]+)\[([0-9]+)\]$/i
                    res = res.send($0)
                    res = res[$1.to_i]
                else
                    res = res.send(n)
            end
        end
        (res.is_a? RbVmomi::BasicTypes::Base)? res.pretty_inspect : res.to_s
    end

    def self.power(vm, command)
        case command
            when :on
                vm.PowerOnVM_Task!.wait_for_completion
            when :off
                vm.PowerOffVM_Task!.wait_for_completion
            when :suspend
                vm.SuspendVM_Task!.wait_for_completion
            when :reset
                vm.ResetVM_Task!.wait_for_completion
            else
                nil
        end
    end

    def self.cycle(vm, command)
        case command
            when :standby
                vm.StandbyGuest!.wait_for_completion
            when :reboot
                vm.RebootGuest!.wait_for_completion
            when :shutdown
                vm.ShutdownGuest!.wait_for_completion
            else
                nil
        end
    end

    def self.console(vm)
        conn,response,oid = vm._connection,vm.AcquireMksTicket,vm._ref
        ticket,sslThumbprint = response.ticket,response.sslThumbprint.gsub(":","-")
        host,port = conn.host,conn.http.port.to_s
        return "vmrc://clone:cst-VCT-#{ticket}--tp-#{sslThumbprint}@#{host}:#{port}/?moid=#{oid}"
    end

    def self.attributes(vm, attributes)
        attributes.map {|attr|
            begin
                case attr
                    when /^REF$/i
                        vm._ref
                    when /^PATH$/i
                        vm.pretty_path
                    when /^STORAGE$/i
                        vm.storage.perDatastoreUsage.map {|x| x.datastore.to_s}.join(",")
                    when /^DATASTORE$/i
                        vm.datastore.map {|x| x.name.to_s}.pretty_inspect
                    when /^NETWORK$/i
                        vm.network.map {|x| x.to_s}.pretty_inspect
                    when /^DISKS$/i
                        vm.disks.map {|x| x.backing.fileName}.pretty_inspect
                    when /^LAYOUT\./i
                        VmHelper.resolve(vm, attr.split("."))
                    when /^DISK\[([0-9]+)\]\./i
                        res = vm.disks["#{$0}".to_i]
                        slice = attr.split(".")
                        slice.shift
                        VmHelper.resolve(res, slice)
                    when /^SNAPSHOT\[([0-9]+)\]\./i
                        res = vm.snapshot.rootSnapshotList["#{$0}".to_i]
                        slice = attr.split(".")
                        slice.shift
                        VmHelper.resolve(res, slice)
                    when /^SUMMARY\./i
                        res = vm.summary
                        slice = attr.split(".")
                        slice.shift
                        VmHelper.resolve(res, slice)
                    when /^CONFIG\./i
                        res = vm
                        VmHelper.resolve(vm, attr.split("."))
                    when /^CONSOLE$/i
                        self.console(vm)
                    else
                        VmHelper.resolve(vm, attr.split("."))
                end
            rescue Exception
                '?'
            end
        }
    end
end

class Commands
    def self.filter(vm, dummy) end
    def self.select(vm, dummy) end

    def self.get(vm, attributes)
        if vm.is_a? Array
            return vm.map {|x| self.get(x, attributes)}
        end
        attrs = attributes.split(',')
        attrs.zip(VmHelper.attributes(vm, attrs)).each {|k,v|
            puts ["get",vm._ref,k,v.to_s].join(':')
        }
    end

    def self.list(vm, attributes, ifs: ":")
        if not attributes.is_a? String or attributes.length == 0 then
            attributes = "name,guestHeartbeatStatus,runtime.powerState,summary.config.numCpu,summary.quickStats.overallCpuUsage,summary.quickStats.hostMemoryUsage,guest_ip,summary.quickStats.uptimeSeconds".split(',')
        else
            attributes = attributes.split(",")
        end

        vm = [vm] if not vm.is_a? Array
        STDERR.puts (['list-header'] << attributes).join(ifs) << "\n"
        vm.each {|vm|
            puts (['list',vm._ref] << VmHelper.attributes(vm, attributes).map{|x|x.gsub("\n"," ").chomp}).join(ifs) << "\n"
        }
    end

    def self.rename(vm, name)
        if vm.is_a? Array
            STDERR.puts "Refusing to rename #{vm.length} virtualmachines. Use select\n"
            puts ["!rename",name,emdash(TypeError.new),vm.map {|x|x._ref.to_s}.join(',')].join(":") + "\n"
            return
        end

        oldname = vm.config.name
        begin
            vm.Rename_Task(newName: name).wait_for_completion
            newname = vm.config.name
            STDERR.puts "Renamed virtualmachine from #{oldname} to #{newname}\n"
        rescue Exception => e
            puts ["!rename",vm._ref,emdash(e),oldname].join(":") + "\n"
            false
        else
            puts ["rename",vm._ref,oldname,newname].join(":") + "\n"
            true
        end
    end

    def self.power(vm, command)
        if vm.is_a? Array
            return vm.map {|x| self.power(x, command)}
        end

        name,oldstate,state = vm.name,vm.runtime.powerState,command.to_sym
        begin
            VmHelper.power(vm, state)
        rescue RbVmomi::VIM::InvalidPowerState => e
            STDERR.puts "Unable to change runtime.powerState for #{name} from #{oldstate} to #{state.to_s}\n"
            puts ["!power",vm._ref,emdash(e),oldstate,state.to_s].join(':') + "\n"
            false
        else
            newstate = vm.runtime.powerState
            STDERR.puts "Changed runtime.powerState for #{name} from #{oldstate} to #{newstate}\n"
            puts ["power",vm._ref,oldstate,newstate].join(':') + "\n"
            true
        end
    end

    def self.cycle(vm, command)
        if vm.is_a? Array
            return vm.map {|x| self.cycle(x, command)}
        end
        STDERR.puts "Using VMware tools to #{command.upcase} the virtual machine #{name}.\n"

        name,oldstate,state = vm.name,vm.runtime.powerState,command.to_sym
        begin
            VmHelper.cycle(vm, command)
        rescue RbVmomi::VIM::InvalidState => e
            STDERR.puts "Unable to change runtime.powerState for " << vm.name << " from " << vm.runtime.powerState << " to " << newstate << "\n"
            puts ["!cycle",vm._ref,emdash(e),oldstate,state.to_s].join(':') + "\n"
            false
        else
            newstate = vm.runtime.powerState
            STDERR.puts "State changed from #{state} to #{newstate}\n"
            puts ["cycle",vm._ref,oldstate,newstate].join(':') + "\n"
            true
        end
    end

    def self.snapshot(vm)
        STDERR.puts "Snapshot capability unimplemented\n"
    end

    def self.console(vm)
        if vm.is_a? Array
            vm.map {|x|self.console(x)}
            return
        end
        begin
            uri = VmHelper.console(vm) + "&name=#{vm.name}"
        rescue Exception => e
            puts ['!console',vm._ref,emdash(e)].join(':') + "\n"
        else
            puts ['console',vm._ref,uri].join(':') + "\n"
            true
        end
    end

    def self.destroy(vm, confirmation)
        vm = vm.find {|x| x._ref.to_s == confirmation} if vm.is_a? Array
        if vm == nil
            STDERR.puts "Unable to find machine matching %{confirmation}.\n"
            puts ["!removed",vm._ref,emdash(NameError.new),confirmation].join(":") + "\n"
            return
        end

        name,uuid = vm.name,vm.config.uuid
        if vm._ref.to_s != confirmation then
            STDERR.puts "Invalid machine identifier. Refused to remove virtualmachine #{name}\n"
            puts ["!removed",vm._ref,emdash(NameError.new),confirmation].join(":") + "\n"
            return
        end

        begin
            STDERR.puts "Removing virtualmachine #{name} -- #{uuid}\n"
            vm.Destroy_Task.wait_for_completion
        rescue Exception => e
            puts ["!removed",vm._ref,emdash(e),name,uuid].join(":") + "\n"
            false
        else
            puts ["removed",vm._ref,name,uuid].join(":") + "\n"
            true
        end
    end

    def self.clone(vm, path)
        STDERR.puts "Clone capability unimplemented\n"
        exit 1

#        spec = VmHelper.getSpec(vm)
#
#        if path.include? "/"
#            name =
#        else
#            if vm.parent.is_a? RbVmomi::VIM::Folder
#                folder = vm.parent
#            else
#                folder = dc.vmFolder.traverse(config.vm_base_path, RbVmomi::VIM::Folder, true)
#            end
#        end
#        STDERR.puts "Cloning " << vm.name << " to " << folder.pretty_path << "/" << name << "\n"
#        #task = vm.CloneVM_Task(folder: folder, name: name, spec: spec)
#
#        pp spec
#        puts "cloned:" << uuid << ":" << new_vm.config.uuid << "\n"
#
#        #new_vm = task.wait_for_completion.vm
#        #puts "Created virtualmachine " << new_vm.pretty_path << "\n"
    end
end

def emdash(e)
    return e.to_s.gsub(':','--')
end

def connect(config)
    conn = RbVmomi.connect(**config)
    root = conn.serviceInstance.content.rootFolder
    return root.childEntity.grep(RbVmomi::VIM::Datacenter)
end

def choose(all, filter)
    if filter.include? "=" then
        field,pattern = filter.split("=",2)
    else
        field,pattern = "name",filter
    end

    all.select do|vm|
        vm if File.fnmatch(pattern, VmHelper.attributes(vm,[field])[0].to_s)
    end
end

def extractCommands(args)
    args = args.dup
    result = []
    while args.length > 0
        comm = args.shift.downcase.to_sym
        if not (Commands.methods-Object.methods).include? comm
            STDERR.puts "Skipping unknown command " << comm.to_s << "\n"
            next
        end

        res = [comm]
        for _,name in Commands.method(comm).parameters.select {|x,y| x == :req and y != :vm}
            res << args.shift
        end
        result << res
    end
    result
end

def main(args)
    options = Options.new.parse(args)
    STDERR.puts "Connecting to #{options[:config][:user]}@#{options[:config][:host]}:#{options[:config][:port] or 443}\n"
    dc = connect(options[:config])
    if dc.length > 1 || options[:listdatacenter]
        STDERR.puts "Listing datacenters..."
        dc.each {|x|
            puts "#{x.name}\n"
        }
        exit 1
    end

    if dc.length == 0
        STDERR.puts "Unable to locate any datacenters"
        exit 1
    end

    if dc.length > 1
        dc = dc.find {|x| File.fnmatch(options[:datacenter],x.name)}
        STDERR.puts "Using datacenter #{dc.name}\n"
    else
        dc = dc[0]
        STDERR.puts "Defaulting to datacenter #{dc.name}\n"
    end

    if dc.vmFolder.childEntity.count == 0 || options[:listresource]
        if dc.hostFolder.children.count > 1 || options[:listresource]
            STDERR.puts "Listing compute resources..."
            dc.hostFolder.children.each {|x|
                puts "#{x.name}\n"
            }
            exit 1
        end
        if dc.hostFolder.children.count > 1
            resource = dc.hostFolder.children.find {|x| File.fnmatch(options[:resource], x.name) }
            STDERR.puts "Using resource #{resource.name}\n"
        else
            resource = dc.hostFolder.children[0]
            STDERR.puts "Defaulting to resource #{resource.name}\n"
        end
        hostvms = resource.host.map{|x| x.vm.to_a}.flatten(1)
        res = hostvms.grep(RbVmomi::VIM::VirtualMachine).to_a
    else
        res = dc.vmFolder.children
        options[:path].split("/").each {|p|
            res = res.find {|n| File.fnmatch(p, n.name)}.children
        }

        if options[:listpath]
            STDERR.puts "Listing current path : " << options[:path]
            res.each {|x|
                puts "#{x.name}\n"
            }
            exit 1
        end

        res = res.grep(RbVmomi::VIM::VirtualMachine).to_a
    end

    machines = res
    if machines.length == 0
        STDERR.puts "Unable to locate any virtual-machines\n"
        exit 1
    end

    selected = machines.dup
    extractCommands(ARGV).each do|command,*args|
        STDERR.puts ['command',command.to_s,args.join(',')].join(":") << "\n"
        case command
            when :filter
                selected = (args == ['-'])? machines.dup : choose(machines, args.join(''))
            when :select
                selected = choose(machines, args.join(''))[0]
            else
                args = [''] if args == ['-']
                Commands.send(command, selected, *args)
        end
    end
    0
end

exit main(ARGV)
