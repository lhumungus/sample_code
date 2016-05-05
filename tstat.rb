  def self.parse_gen(monurl, managed_only = false)
    ##  Modified this to use our special version of the xml
    
    ##  This code uses open-uri to open the monurl URL and return it as a tmpfile pointer;
    ##    the .read then reads the entire file in as a string (in this case it will be an
    ##    an XML string).  That file pointer has then fully expired.  The string is then 
    ##    parsed by Ox into an OX::DOCUMENT, comprised of OX:ELEMENTS 
    doc = Ox.parse(open(monurl).read)

    plist = doc.root
    dict = Hash.new

    output = Array.new

    ##  Basically keep iterating down till you get to where nodes[0].class == String, then
    ##    you add this to your Hash.
    plist.nodes.each do |n|
      if n.is_a?(::Ox::Element)
        if n.nodes[0] == "1"
          ##  This is the 'success' tag, and should be the LAST node returned
          ## puts "DEBUG  we are N=#{n.nodes.inspect}.  This is the 'success' tag, the last thing we should see."
          next
        end
        dict = node_to_hash(n, dict)
        
        ##  Let's create a Tstat Object from this Hash
        obj = Tstat.new(dict)
        output << obj
      else
        raise "Not an Ox::Element:  NOTOX=#{n.class} NOTOX=#{n.inspect}"
      end
    end

    ##  Iterate through each Tstat, and determine if it's managed or not
    ##  Output is array of Tstat objects
    output
  end
