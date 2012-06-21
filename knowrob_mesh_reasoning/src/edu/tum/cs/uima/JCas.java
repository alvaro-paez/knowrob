/*******************************************************************************
 * Copyright (c) 2012 Stefan Profanter.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the GNU Public License v3.0
 * which accompanies this distribution, and is available at
 * http://www.gnu.org/licenses/gpl.html
 * 
 * Contributors:
 *     Stefan Profanter - initial API and implementation, Year: 2012
 ******************************************************************************/
package edu.tum.cs.uima;

import java.io.Serializable;
import java.util.LinkedList;

/**
 * Dummy for UIMA Framework
 * 
 * @author Stefan Profanter
 * 
 */
public abstract class JCas implements Serializable {
	/**
	 * auto generated
	 */
	private static final long			serialVersionUID	= -2177164580358313559L;
	/**
	 * List of annotations for this CAS
	 */
	protected LinkedList<Annotation>	annotations			= new LinkedList<Annotation>();

	/**
	 * Dummy for UIMA framework
	 * 
	 * @return list of annotations
	 */
	public LinkedList<Annotation> getAnnotations() {
		return annotations;
	}

	/**
	 * Dummy for UIMA framework
	 * 
	 * @param annotations
	 *            value to set
	 */
	public void setAnnotations(LinkedList<Annotation> annotations) {
		this.annotations = annotations;
	}
}
