-- input: a path to a class file to turn into a container
--[[ objective: 
 -- create a backup file (you never know!)
 -- on the original file:
	 -- add @TestContainer where needed
	 -- remove all @Test and @Timeout
	 
 -- on new file:
    -- change extends... into extends class
	-- remove all methods except tests
	-- change test bodies into invocations to super
	
usage C:\luaprograms\ToCollection_v2.lua FilePath [-verbose]
--]]

-- created by cregecambrin on 2017/12/20
windows_platform_specific = {
  separator		=	'\\'
, copyFile 		= 	function(fileFrom, fileTo) 
    			 		return os.execute("copy " .. fileFrom .. " " .. fileTo)
             		end
, deleteFile 	= 	function(fileToDelete)
                 		return os.execute("del " .. fileToDelete)
                 	end
, renameDir 	= 	function(oldName, newName)
                 		return os.execute("rename " .. oldName .. " " .. newName)
                 	end
}


do 
logEnabler = false
insertComment = "/**\n * Edited by automatic script " .. arg[0] .. " on " .. os.date() .. "\n */\n"

local hardprint = print
local function print(...)
  if (not logEnabler) then
     return
  end
  
  local printResult = ""
  for i=1,select("#",...) do
	local v = select(i,...)
	printResult = printResult .. tostring(v) .. "\t"
  end
  printResult = printResult .. "\n"
  return hardprint(printResult)
end

local function copyFile(fileFrom, fileTo, forceCopy)
  local file = assert(io.open(fileFrom, "r"))
  file.close()

  finalFileTo = fileTo
  file = io.open(finalFileTo, "r")

  if (file) then  -- destination file already exisats
    if (not forceCopy) then
  	  assert(not(file), "Destination file " .. finalFileTo .. " already exists!")
    else
      local i = 1
      repeat
        finalFileTo = fileTo .. "(" .. i .. ")"
        file = io.open(finalFileTo, "r")
        i = i+1
      until (not file)
    end
  end
  print ('Copy ', fileFrom, ' to', finalFileTo)
  windows_platform_specific.copyFile(fileFrom,finalFileTo)
end

local function deleteFile(fileToDelete)
  local file = io.open(fileToDelete, "r")
  file:close()
  print ('Deleting ', fileToDelete)
  if (file) then
   windows_platform_specific.deleteFile(fileToDelete)
  end
end

local function getLastInString(inputString, tofind)
    local i
	repeat 
	  j = string.find(inputString, tofind, (i or 0) +1)
	  if (j) then
	     i = j
	  end 
	until not j;
	return i 
end

local function splitFileName(fullFileName)
	local sfpos = getLastInString(fullFileName, "[.]")
	local bspos = getLastInString(fullFileName, windows_platform_specific.separator)
	local directory = bspos and (string.sub(fullFileName,1,bspos-1))
	local fileName  = bspos and (string.sub(fullFileName,bspos+1,(sfpos and sfpos-1)))
	local suffix    = sfpos and (string.sub(fullFileName,sfpos))
	local noSuffix  = sfpos and (string.sub(fullFileName,1,sfpos-1))
	return directory,fileName,suffix,noSuffix
end

local function processContainerFile(fileName, originalClassName)
  print("Processing Container file...")
  local file = assert(io.open(fileName, "r"))
  allFile = file:read("*all")
  file:close()
  
  -- add import for TestContainer
  local newImport = "import com.nitro.qe.ntf.annotation.TestContainer;\n"
  allFile, numRepl = allFile:gsub("package(.-)import ", "package%1" .. newImport .. "import ") 
  print(numRepl or 0, " import added")


  -- replace class header with new header for container
  headerPattern = "public[ \\n\\t\\r]+class[ \\n\\t\\r]+" .. originalClassName .. "[ \\n\\t\\r]+extends[ \\n\\t\\r]+NitroProUITestBase"
  replacePattern = "@TestContainer\npublic abstract class " .. originalClassName .. " extends NitroProUITestBase"
  allFile, numRepl = allFile:gsub(headerPattern, insertComment .. replacePattern) 
  print(numRepl or 0, " instances replaced with new header")
  
  -- remove all @Test( ...
  testPattern = "[ \\t]*@Test[(][^\n\r]*[\n\r]"
  allFile, numRepl = allFile:gsub(testPattern, "") 
  print(numRepl or 0, " instances of @Test removed")
  
  -- remove all @TestCase("...
  testPattern = "[ \\t]*@TestCase[(][^\n\r]*[\n\r]"
  allFile, numRepl = allFile:gsub(testPattern, "") 
  print(numRepl or 0, " instances of @TestCase removed")

  file = assert(io.open(fileName, "w"))
  file:write(allFile)
  file:close()
end

local function processDerivedFile(fileName, originalClassName)
  print("Processing original file...")
  local file = assert(io.open(fileName, "r"))
  allFile = file:read("*all")
  file:close()  
  
  -- replace class header with new header that inherits from container
  local headerPattern = "public[ \\n\\t\\r]+class[ \\n\\t\\r]+" .. originalClassName .. "[ \\n\\t\\r]+extends[ \\n\\t\\r]+NitroProUITestBase"
  local replacePattern = "public class " .. originalClassName .. "Nitro extends " .. originalClassName 
  allFile, numRepl = allFile:gsub(headerPattern, insertComment .. replacePattern) 
  print(numRepl or 0, " instances replaced with new header")

  -- remove everything between class header and first test 
  local toFirstTestPattern = replacePattern .. ".-@Test[(]" -- notice .- (the "non greedy" pattern)
  allFile, numRepl = allFile:gsub(toFirstTestPattern, (replacePattern .. " {\n\t@Test(")) 
  print(numRepl or 0, " strings removed before first test")
  
  -- replace everything between a test and next test with invocation to super
  local toNextTestPattern = "@TestCase(.-)[ \n\r\t]+public[ \t\r\n]+void[ \t\r\n]+(.-)[(][)](.-)[{].-@Test[(]"
  replacePattern = "@TEMP_TestCase%1\n\tpublic void %2() %3 {\n\t\tsuper.%2();\n\t}\n\n\t@Test("
  allFile, numRepl = allFile:gsub(toNextTestPattern,replacePattern) 
  print(numRepl or 0, " strings removed for successive tests")

  -- replace everything the last test and end of class with invocation to super
  toNextTestPattern = "@TestCase(.-)[ \n\r\t]+public[ \t\r\n]+void[ \t\r\n]+(.-)[(][)](.-)[{].*[}][ \n\r\t]+[}]"
  replacePattern = "@TEMP_TestCase%1\n\tpublic void %2() %3 {\n\t\tsuper.%2();\n\t}\n}"
  allFile, numRepl = allFile:gsub(toNextTestPattern,replacePattern) 
  print(numRepl or 0, " strings removed for last test")
  
  -- replace TEMP_TestCase with TestCase
  allFile, numRepl = allFile:gsub("@TEMP_TestCase","@TestCase") 

  file = assert(io.open(fileName, "w"))
  file:write(allFile)
  file:close()
end

-- main script
-- read arguments
local usage = "Usage: " .. arg[0] .. " inputFile [-verbose]"
assert(#arg >= 1 and #arg<=2, "Wrong number of arguments! " .. usage)

local inputFile = arg[1]
for i=2,#arg do
  if arg[i]== "-verbose" then
    logEnabler = true
  end
end

local directory, filename, suffix, noSuffix = splitFileName(inputFile)
print(directory, filename, suffix, noSuffix)
assert (filename and suffix and suffix == ".java", "The input file must be a .java file")

-- create a backup file (you never know!)
print("Creating a backup copy (you never know...)")
copyFile(inputFile, inputFile..".bk", true)

-- create the new derived file
derivedFile = noSuffix .. "Nitro.java"
copyFile(inputFile, derivedFile)

-- make all necessary modifications
processContainerFile(inputFile, filename)
processDerivedFile(derivedFile,filename)

-- possible "nice to have": optional: add derivedFile to git? not for now

end